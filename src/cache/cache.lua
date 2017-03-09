-- Create the cache class.
local class = require 'pl.class'
local Cache = class()


--- Initialize a new cache instance.
-- @param tLogger The logger object used for all kinds of messages.
-- @param strID The ID used in the the jonchkicfg.xml to reference this instance.
function Cache:_init(tLogger, strID)
  self.tLogger = tLogger
  self.strRepositoryRootPath = nil
  self.strID = strID
  self.tSQLEnv = nil
  self.strDatabaseName = 'cache.sqlite3'

  -- The "penlight" module is always useful.
  self.pl = require'pl.import_into'()

  self.artifact = require 'ArtifactConfiguration'
  self.date = require 'date'
  self.sqlite3 = require 'luasql.sqlite3'

  self.tLogger:debug('[Cache] Created cache "%s".', strID)
  self.strLogID = string.format('[Cache "%s"]', strID)

  self.tSQLEnv = self.sqlite3.sqlite3()
end



--- Check the table structure.
-- This function compares the present structure of a table in a database with a required structure.
-- It detects if the running software requires a different table structure than the database provides.
-- 
-- This is done by comparing the SQL statement which is used to create the present table with the
-- create statement from the software. SQLite3 provides the create statements for each table in a database.
-- 
-- If the table is not present yet, it is created with the structure from the software.
-- If the present table structure in the database differs from the structure required by the software, the table is deleted and re-created.
-- If the present table structure matches the structure required by the software, the existing table is used.
-- @param tSQLCon The SQL connection object.
-- @param strTableName The name of the table.
-- @param strCreateStatement The create statement for the table.
-- @return If the function fails, it returns nil.
--         If the table was created or deleted and re-created, it returns true.
--         Otherwise an existing table is re-used and the function returns false.
function Cache:_sql_create_table(tSQLCon, strTableName, strCreateStatement)
  -- Be pessimistic.
  local tResult = nil

  -- Compare the current "CREATE" statement with the statement of the existing table.
  local tCursor = tSQLCon:execute(string.format('SELECT sql FROM sqlite_master WHERE name="%s"', strTableName))
  if tCursor==nil then
    -- Error!
    self.tLogger:error('%s Failed to query the last create statement for table "%s".', self.strLogID, strTableName)
  else
    local strDatabaseCreateStatement = tCursor:fetch()
    tCursor:close()
    if strDatabaseCreateStatement==strCreateStatement then
      self.tLogger:debug('%s The table structure for "%s" is up to date.', self.strLogID, strTableName)
        self.tLogger:debug('%s Create statement: "%s"', self.strLogID, strCreateStatement)

      -- Do not create the table data from scratch.
      tResult = false
    elseif strDatabaseCreateStatement==nil then
      self.tLogger:debug('%s The table "%s" does not exist yet. Create it now.', self.strLogID, strTableName)
      self.tLogger:debug('%s Create statement: "%s"', self.strLogID, strCreateStatement)

      -- Create a new table.
      local tSqlResult, strError = tSQLCon:execute(strCreateStatement)
      if tSqlResult==nil then
        self.tLogger:error('%s Failed to create the table "%s": %s', self.strLogID, strTableName, strError)
      else
        tSQLCon:commit()

        -- Create the table data from scratch.
        tResult = true
      end
    else
      self.tLogger:debug('%s The table "%s" has a different create statement. Delete and recreate it.', self.strLogID, strTableName)
      self.tLogger:debug('%s Old create statement: "%s"', self.strLogID, strDatabaseCreateStatement)
      self.tLogger:debug('%s New create statement: "%s"', self.strLogID, strCreateStatement)

      -- Delete the old table.
      local tSqlResult, strError = tSQLCon:execute(string.format('DROP TABLE %s', strTableName))
      if tSqlResult==nil then
        self.tLogger:error('%s Failed to delete the table "%s": %s', self.strLogID, strTableName, strError)
      else
        tSQLCon:commit()

        -- Re-create a new table.
        local tSqlResult, strError = tSQLCon:execute(strCreateStatement)
        if tSqlResult==nil then
          self.tLogger:error('%s Failed to re-create the table "%s": %s', self.strLogID, strTableName, strError)
        else
          tSQLCon:commit()

          -- Create the table data from scratch.
          tResult = true
        end
      end
    end
  end

  return tResult
end



--- Scan the repository.
-- Scan one folder of the repository. Sum up all file sizes and collect the
-- ages of each entry.
-- @param tSQLDatabase The database handle.
-- @return In case of an error the function returns nil.
--         If the function succeeded it returns true.
function Cache:_scan_repo(tSQLDatabase)
  -- Be optimistic.
  local tResult = true

  -- Loop over all files in the repository.
  for strRoot,astrDirs,astrFiles in self.pl.dir.walk(self.strRepositoryRootPath, false, true) do
    -- Loop over all files in the current directory.
    for _,strFile in pairs(astrFiles) do
      -- Get the full path of the file.
      local strFullPath = self.pl.path.join(strRoot, strFile)
      -- Get the extension of the file.
      local strExtension = self.pl.path.extension(strFullPath)
      -- Is this a configuration file?
      if strExtension=='xml' then
        -- Try to parse the file as a configuration.
        local cArtifact = self.artifact()
        local tResult = cArtifact:parse_configuration_file(strFullPath)
        if tResult==true then
          self.tLogger:debug('Found configuration file "%s".', strFullPath)
        else
          self.tLogger:warning('%s Ignoring file "%s". It is no valid artifact configuration.', self.strLogID)
        end
      end
    end
  end

  return tResult
end



--- Set the configuration of the cache instance.
-- @param strRepositoryRootPath The root path of the repository.
function Cache:configure(strRepositoryRootPath)
  local tResult = nil


  -- Convert this to an absolute path.
  local strAbsRepositoryRootPath = self.pl.path.abspath(strRepositoryRootPath)
  self.tLogger:debug('%s Set the repository root path to "%s".', self.strLogID, strAbsRepositoryRootPath)
  self.strRepositoryRootPath = strAbsRepositoryRootPath

  -- The path was already created by the system configuration.
  -- If it does not exist or it is no directory, this is an error.
  if self.pl.path.exists(strAbsRepositoryRootPath)~=strAbsRepositoryRootPath then
    self.tLogger:error('%s The repository root path "%s" does not exist.', self.strLogID, strAbsRepositoryRootPath)
  elseif self.pl.path.isdir(strAbsRepositoryRootPath)~=true then
    self.tLogger:error('%s The repository root path "%s" is no directory.', self.strLogID, strAbsRepositoryRootPath)
  else
    -- Append the database name to the path.
    local strDb = self.pl.path.join(strAbsRepositoryRootPath, self.strDatabaseName)

    -- Try to open an existing SQLite3 database in the root path.
    -- If the database does not exist yet, create it.
    self.tLogger:debug('%s Opening database "%s".', self.strLogID, strDb)
    local tSQLDatabase, strError = self.tSQLEnv:connect(strDb)
    if tSQLDatabase==nil then
      self.tLogger:error('%s Failed to open the database "%s": %s', self.strLogID, strDb, strError)
    else
      -- Construct the "CREATE" statement for the "cache" table.
      local strCreateStatement = 'CREATE TABLE cache (iId INTEGER PRIMARY KEY, strGroup TEXT NOT NULL, strModule TEXT NOT NULL, strArtifact TEXT NOT NULL, strVersion TEXT NOT NULL, strConfigurationPath TEXT NOT NULL, strConfigurationHashPath TEXT NOT NULL, iConfigurationSize INTEGER NOT NULL, strArtifactPath TEXT NOT NULL, strArtifactHashPath TEXT NOT NULL, iArtifactSize INTEGER NOT NULL, iCreateDate INTEGER NOT NULL, iLastUsedDate INTEGER NOT NULL, strSourceUrl TEXT_NOT_NULL)'
      tResult = self:_sql_create_table(tSQLDatabase, 'cache', strCreateStatement)
      if tResult==nil then
        tSQLDatabase:close()
        self.tLogger:error('%s Failed to create the table.', self.strLogID)
      elseif tResult==true then
        self.tLogger:debug('%s Rebuild the cache information.', self.strLogID)
        tResult = self:_scan_repo(tSQLDatabase)
      end
    end
  end

  return tResult
end



--- A sort function for the age attributes of 2 entries.
-- This function is used in the table.sort function. It gets 2 entries which
-- must be tables with an "age" attribute each. Both "age" entries are
-- converted to date objects which are compared.
-- NOTE: the function must be static.
-- @param tEntry1 The first entry.
-- @param tEntry2 The second entry.
-- @return true if tEntry1.age is smaller (i.e. earlier) than tEntry2.age
function Cache.sort_age_table(tEntry1, tEntry2)
	local tDate1 = self.date(tEntry1.age)
	local tDate2 = self.date(tEntry2.age)

	return tDate1<tDate2
end


--[[
-- This is an example path with lots of content.
strRepoPath = "/home/baccy/Coding/secmem_contents"

-- Scan the repository.
local atFileAge = {}
local fOk,uiTotalSize = scan_repo(strRepoPath, ".lua", atFileAge)
if fOk~=true then
	print("Failed to scan the repository: " .. uiTotalSize)
else
	print(string.format("The repository uses %d bytes now.", uiTotalSize))

	-- Set the maximum repository size to 100MB.
	local uiMaximumSize = 100*1024*1024

	if uiTotalSize>uiMaximumSize then
		local uiOversize = uiTotalSize - uiMaximumSize
		print(string.format("The repository exceeds the maximum size of %d bytes. Looking for %d bytes.", uiMaximumSize, uiOversize))

		-- Sort the entries to get the oldest entries.
		table.sort(atFileAge, sort_age_table)

		-- Collect the first entries of the sorted table until the oversize is reached.
		local uiCollectedSize = 0
		local atDelete = {}
		for iCnt, tAttr in pairs(atFileAge) do
			table.insert(atDelete, tAttr)
			uiCollectedSize = uiCollectedSize + tAttr.size
			if uiCollectedSize>=uiOversize then
				break
			end
		end

		print("Files to delete:")
		for iCnt, tAttr in pairs(atDelete) do
			print(string.format("Delete %s ... (not really)", tAttr.file))
		end
	end
end
--]]

return Cache
