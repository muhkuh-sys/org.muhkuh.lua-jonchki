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

  -- Get the hash abstraction.
  local cHash = require 'Hash'
  self.hash = cHash(tLogger)

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.date = require 'date'
  self.sqlite3 = require 'luasql.sqlite3'

  self.tLogger:debug('[Cache] Created cache "%s".', strID)
  self.strLogID = string.format('[Cache "%s"]', strID)

  self.tSQLEnv = self.sqlite3.sqlite3()
  self.tSQLDatabase = nil

  -- Initialize the path template string.
  self.strPathTemplate = nil

  -- No maximum size set yet.
  self.ulMaximumSize = nil

  -- Initialize the statistics.
  self.uiStatistics_RequestsConfigHit = 0
  self.uiStatistics_RequestsArtifactHit = 0
  self.uiStatistics_RequestsConfigMiss = 0
  self.uiStatistics_RequestsArtifactMiss = 0
  self.uiStatistics_ServedBytesConfig = 0
  self.uiStatistics_ServedBytesArtifact = 0
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



function Cache:_replace_path(cArtifact, strExtension)
  local tInfo = cArtifact.tInfo

  -- Convert the group to a list of folders.
  local strSlashGroup = self.pl.stringx.replace(tInfo.strGroup, '.', '/')

  -- Get the version string if there is a version object.
  local strVersion = nil
  if tInfo.tVersion~=nil then
    strVersion = tInfo.tVersion:get()
  end

  -- Construct the replace table.
  local atReplace = {
    ['dotgroup'] = tInfo.strGroup,
    ['group'] = strSlashGroup,
    ['module'] = tInfo.strModule,
    ['artifact'] = tInfo.strArtifact,
    ['version'] = strVersion,
    ['extension'] = strExtension
  }

  -- Replace the keywords.
  return string.gsub(self.strPathTemplate, '%[(%w+)%]', atReplace)
end



function Cache:_get_configuration_paths(cArtifact)
  local strPathConfiguration = self:_replace_path(cArtifact, 'xml')
  local strPathConfigurationHash = self:_replace_path(cArtifact, 'xml.hash')

  return strPathConfiguration, strPathConfigurationHash
end



function Cache:_get_artifact_paths(cArtifact)
  local strExtension = cArtifact.tInfo.strExtension
  local strPathArtifact = self:_replace_path(cArtifact, strExtension)
  local strPathArtifactHash = self:_replace_path(cArtifact, string.format('%s.hash', strExtension))

  return strPathArtifact, strPathArtifactHash
end



-- Search for the GMAV in the database.
-- @return nil for an error, false if nothing was found, a number on success.
function Cache:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local atAttr = nil


  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLogger:error('%s No connection to a database established.', self.strLogID)
  else
    local strVersion = tVersion:get()
    local strQuery = string.format('SELECT * FROM cache WHERE strGroup="%s" AND strModule="%s" AND strArtifact="%s" AND strVersion="%s"', strGroup, strModule, strArtifact, strVersion)
    local tCursor, strError = tSQLDatabase:execute(strQuery)
    if tCursor==nil then
      self.tLogger:error('%s Failed to search the cache for an entry: %s', self.strLogID, strError)
    else
      repeat
        local atData = tCursor:fetch({}, 'a')
        if atData~=nil then
          if atAttr~=nil then
            self.tLogger:error('%s The cache database is broken. It has multiple entries for %s/%s/%s/%s.', self.strLogID, strGroup, strModule, strArtifact, strVersion)
            -- TODO: rebuild the cache here with tResult = self:_rebuild_complete_cache(tSQLDatabase)
            break
          else
            atAttr = atData
          end
        end
      until atData==nil

      -- Close the cursor.
      tCursor:close()

      -- Found exactly one match?
      if atAttr==nil then
        -- Nothing found. This is no error.
        tResult = false
      else
        -- Exactly one match found. Return the ID.
        tResult = true
      end
    end
  end

  return tResult, atAttr
end



function Cache:_database_add_configuration(tSQLDatabase, cArtifact)
  local tResult = nil


  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  local tInfo = cArtifact.tInfo
  local iConfigurationFileSize = self.pl.path.getsize(strPathConfiguration)

  local strQuery = string.format('INSERT INTO cache (strGroup, strModule, strArtifact, strVersion, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, iCreateDate, iLastUsedDate) VALUES ("%s", "%s", "%s", "%s", "%s", "%s", %d, strftime("%%s","now"), strftime("%%s","now"))', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get(), strPathConfiguration, strPathConfigurationHash, iConfigurationFileSize)

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLogger:error('%s Failed to add the new entry to the cache: %s', self.strLogID, strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_add_artifact(tSQLDatabase, cArtifact)
  local tResult = nil


  -- Get the paths.
  local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)
  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  local tInfo = cArtifact.tInfo
  self.tLogger:debug('%s Adding artifact %s/%s/%s V%s', self.strLogID, tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get())

  local iConfigurationFileSize = self.pl.path.getsize(strPathConfiguration)
  local iArtifactFileSize = self.pl.path.getsize(strPathArtifact)

  local strQuery = string.format('INSERT INTO cache (strGroup, strModule, strArtifact, strVersion, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, strArtifactPath, strArtifactHashPath, iArtifactSize, iCreateDate, iLastUsedDate) VALUES ("%s", "%s", "%s", "%s", "%s", "%s", %d, "%s", "%s", %d, strftime("%%s","now"), strftime("%%s","now"))', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get(), strPathConfiguration, strPathConfigurationHash, iConfigurationFileSize, strPathArtifact, strPathArtifactHash, iArtifactFileSize)

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLogger:error('%s Failed to add the new entry to the cache: %s', self.strLogID, strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_update_artifact(atAttr, cArtifact)
  local tResult = nil


  -- Get the paths.
  local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)

  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLogger:error('%s No connection to a database established.', self.strLogID)
  else
    local iId = atAttr.iId
    local iArtifactFileSize = self.pl.path.getsize(strPathArtifact)

    local strQuery = string.format('UPDATE cache SET strArtifactPath="%s", strArtifactHashPath="%s", iArtifactSize=%d, iLastUsedDate=strftime("%%s","now") WHERE iId=%d', strPathArtifact, strPathArtifactHash, iArtifactFileSize, iId)

    local tSqlResult, strError = tSQLDatabase:execute(strQuery)
    if tSqlResult==nil then
      self.tLogger:error('%s Failed to update an entry in the cache: %s', self.strLogID, strError)
    else
      tSQLDatabase:commit()
      tResult = true
    end
  end

  return tResult
end



function Cache:_cachefs_write_configuration(cArtifact)
  local tResult = nil
  local strError


  -- Get the paths.
  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  -- Create the output folder.
  local strPath = self.pl.path.splitpath(strPathConfiguration)
  if strPath=='' then
    tResult = true
  else
    tResult, strError = self.pl.dir.makepath(strPath)
    if tResult~=true then
      self.tLogger:error('%s Failed to create the path "%s": %s', self.strLogID, strPath, strError)
    end
  end

  if tResult==true then
    -- Write the configuration.
    self.tLogger:debug('%s Write the configuration to %s.', self.strLogID, strPathConfiguration)
    tResult, strError = self.pl.utils.writefile(strPathConfiguration, cArtifact.strSource, false)
    if tResult==nil then
      self.tLogger:error('%s Failed to create the file for the configuration at "%s": %s', self.strLogID, strPathConfiguration, strError)
    else
      -- Write the hash of the configuration.
      local strHash = self.hash:generate_hashes_for_string(cArtifact.strSource)
      self.tLogger:debug('%s Write the configuration hash to %s.', self.strLogID, strPathConfigurationHash)
      tResult, strError = self.pl.utils.writefile(strPathConfigurationHash, strHash, false)
      if tResult==nil then
        self.tLogger:error('%s Failed to create the file for the configuration hash at "%s": %s', self.strLogID, strPathConfigurationHash, strError)
      end
    end
  end

  return tResult
end



function Cache:_cachefs_write_artifact(cArtifact, strArtifactSourcePath)
  local tResult = nil
  local strError


  -- Get the paths.
  local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)

  -- Create the output folder.
  local strPath = self.pl.path.splitpath(strPathArtifact)
  if strPath=='' then
    tResult = true
  else
    tResult, strError = self.pl.dir.makepath(strPath)
    if tResult~=true then
      self.tLogger:error('%s Failed to create the path "%s": %s', self.strLogID, strPath, strError)
    end
  end

  if tResult==true then
    -- Copy the artifact.
    self.tLogger:debug('%s Copy the artifact from %s to %s.', self.strLogID, strArtifactSourcePath, strPathArtifact)
    tResult, strError = self.pl.file.copy(strArtifactSourcePath, strPathArtifact, true)
    if tResult~=true then
      self.tLogger:error('%s Failed to copy the artifact from %s to %s: %s', self.strLogID, strArtifactSourcePath, strPathArtifact, strError)
    else
      -- Create the hash for the artifact.
      -- NOTE: get the hash from the source file.
      tResult = self.hash:generate_hashes_for_file(strArtifactSourcePath)
      if tResult==nil then
        self.tLogger:error('%s Failed to get the hash for "%s".', self.strLogID, strArtifactSourcePath)
      else
        local strHash = tResult

        -- Write the hash of the artifact.
        self.tLogger:debug('%s Write the artifact hash to %s.', self.strLogID, strPathArtifactHash)
        tResult, strError = self.pl.utils.writefile(strPathArtifactHash, strHash, false)
        if tResult==nil then
          self.tLogger:error('%s Failed to create the file for the artifact hash at "%s": %s', self.strLogID, strPathArtifactHash, strError)
        end
      end
    end
  end

  return tResult
end



--- Rebuild the complete cache database.
-- Scan one folder of the repository. Sum up all file sizes and collect the
-- ages of each entry.
-- @param tSQLDatabase The database handle.
-- @return In case of an error the function returns nil.
--         If the function succeeded it returns true.
function Cache:_rebuild_complete_cache(tSQLDatabase)
  -- Be optimistic.
  local tResult = true


  self.tLogger:debug('%s Rebuilding cache from path "%s".', self.strLogID, self.strRepositoryRootPath)

  -- Loop over all files in the repository.
  for strRoot,astrDirs,astrFiles in self.pl.dir.walk(self.strRepositoryRootPath, false, true) do
    -- Loop over all files in the current directory.
    for _,strFile in pairs(astrFiles) do
      -- Get the full path of the file.
      local strFullPath = self.pl.path.join(strRoot, strFile)
      -- Get the extension of the file.
      local strExtension = self.pl.path.extension(strFullPath)

      -- Is this a configuration file?
      if strExtension=='.xml' then
        -- Try to parse the file as a configuration.
        local cArtifact = self.ArtifactConfiguration()
        local tArtifactResult = cArtifact:parse_configuration_file(strFullPath)
        if tArtifactResult~=true then
          self.tLogger:debug('%s Ignoring file "%s". It is no valid artifact configuration.', self.strLogID)
        else
          self.tLogger:debug('%s Found configuration file "%s".', self.strLogID, strFullPath)

          -- Generate the paths from the artifact configuration.
          local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)
          local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

          local tInfo = cArtifact.tInfo
          local strGMAV = string.format('%s/%s/%s/%s', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get())

          -- Read the hash of the configuration.
          local strHash, strError = self.pl.utils.readfile(strPathConfigurationHash, false)
          if strHash==nil then
            self.tLogger:debug('%s Failed to read the hash for the configuration of artifact %s: %s', self.strLogID, strGMAV, strError)
          else
            -- Check the hash of the configuration.
            local tCheckResult = self.hash:check_file(strPathConfiguration, strHash, strPathConfigurationHash)
            if tResult~=true then
              self.tLogger:debug('%s The hash for the configuration of artifact %s does not match.', self.strLogID, strGMAV)
            else
              -- Read the hash of the artifact.
              strHash, strError = self.pl.utils.readfile(strPathArtifactHash, true)
              if strHash==nil then
                self.tLogger:debug('%s Failed to read the hash for the artifact %s: %s', self.strLogID, strGMAV, strError)
              else
                -- Check the hash of the artifact.
                local tHashResult = self.hash:check_file(strPathArtifact, strHash, strPathArtifactHash)
                if tHashResult~=true then
                  self.tLogger:debug('%s The hash for the artifact %s does not match.', self.strLogID, strGMAV)
                else
                  -- Add it to the database.
                  tResult = self:_database_add_artifact(tSQLDatabase, cArtifact)
                  if tResult~=true then
                    self.tLogger:error('%s Failed to add the artifact %s to the database.', self.strLogID, strGMAV)
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  self.tLogger:debug('%s Finished rebuilding the cache.', self.strLogID)
  return tResult
end



--- Remove files from the cache which do not belong there.
function Cache:_remove_odd_files(tSQLDatabase)
  -- Be optimistic.
  local tResult = true

  -- Get the full path of the SQLITE3 database file. This one should not be removed.
  local strDatabaseFilename = self.pl.path.join(self.strRepositoryRootPath, self.strDatabaseName)

  self.tLogger:debug('%s Clean the cache by removing odd files from "%s".', self.strLogID, self.strRepositoryRootPath)

  -- Loop over all files in the repository.
  for strRoot,astrDirs,astrFiles in self.pl.dir.walk(self.strRepositoryRootPath, false, true) do
    -- Loop over all files in the current directory.
    for _,strFile in pairs(astrFiles) do
      -- Get the full path of the file.
      local strFullPath = self.pl.path.join(strRoot, strFile)

      -- Keep the database file.
      if strFullPath==strDatabaseFilename then
        self.tLogger:debug('%s Keeping database file "%s".', self.strLogID, strDatabaseFilename)
      else
        -- Search the full path in the database.
        local strQuery = string.format('SELECT COUNT(*) FROM cache WHERE strConfigurationPath="%s" OR strConfigurationHashPath="%s" OR strArtifactPath="%s" OR strArtifactHashPath="%s"', strFullPath, strFullPath, strFullPath, strFullPath)
        local tCursor, strError = tSQLDatabase:execute(strQuery)
        if tCursor==nil then
          self.tLogger:error('%s Failed to search the cache for an entry: %s', self.strLogID, strError)
          tResult = nil
          break
        else
          local atData = tCursor:fetch({})
          if atData==nil then
            self.tLogger:error('%s No result from database for query "%s".', self.strLogID, strQuery)
            tCursor:close()
            tResult = nil
            break
          else
            -- Close the cursor.
            tCursor:close()

            local strResult = atData[1]
            local iCnt = tonumber(strResult)
            if iCnt==0 then
              -- The path was not found in the database.
              self.tLogger:debug('%s Removing stray file "%s".', self.strLogID, strFullPath)
              local tDeleteResult, strError = self.pl.file.delete(strFullPath)
              if tDeleteResult~=true then
                self.tLogger:warn('%s Failed to remove stray file "%s": %s', self.strLogID, strFullPath, strError)
              end
            elseif iCnt==1 then
              -- The path was found in the database.
            else
              self.tLogger:error('%s Invalid result from database for query "%s": "%s"', self.strLogID, strQuery, tostring(strResult))
              tResult = nil
              break
            end
          end
        end
      end
    end
  end

  self.tLogger:debug('%s Finished cleaning the cache.', self.strLogID)
  return tResult
end



function Cache:_enforce_maximum_size(tSQLDatabase, ulFreeSpaceNeeded)
  -- Be optimistic.
  local tResult = true

  local strQuery = string.format('SELECT TOTAL(iConfigurationSize)+TOTAL(iArtifactSize) FROM cache')
  local tCursor, strError = tSQLDatabase:execute(strQuery)
  if tCursor==nil then
    self.tLogger:error('%s Failed to get the total size of the cache: %s', self.strLogID, strError)
    tResult = nil
  else
    local atData = tCursor:fetch({})
    if atData==nil then
      self.tLogger:error('%s No result from database for query "%s".', self.strLogID, strQuery)
      tCursor:close()
      tResult = nil
    else
      -- Close the cursor.
      tCursor:close()

      local strResult = atData[1]
      local iTotalSize = tonumber(strResult)
      if iTotalSize==nil then
        self.tLogger:error('%s Invalid result from database for query "%s": "%s"', self.strLogID, strQuery, tostring(strResult))
        tResult = nil
      else
        self.tLogger:debug('%s The total size of the cache is %d bytes.', self.strLogID, iTotalSize)
        -- Check if the requested free space would grow the cache over the allowed maximum.
        local iBytesToSave = (iTotalSize + ulFreeSpaceNeeded) - self.ulMaximumSize
        if iBytesToSave>0 then
          self.tLogger:debug('%s Need to shrink the cache by %d bytes.', self.strLogID, iBytesToSave)

          -- Collect all files to delete in this table.
          local astrDeleteFiles = {}
          local aIdDeleteSql = {}
          local iBytesSaved = 0

          -- Loop over all artifacts starting with the oldest "last used" date.
          strQuery = string.format('SELECT iId, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, strArtifactPath, strArtifactHashPath, iArtifactSize FROM cache ORDER BY iLastUsedDate ASC')
          tCursor, strError = tSQLDatabase:execute(strQuery)
          if tCursor==nil then
            self.tLogger:error('%s Failed to get all cache entries: %s', self.strLogID, strError)
            tResult = nil
          else
            repeat
              local atData = tCursor:fetch({}, 'a')
              if atData~=nil then
                -- Add all paths to the delete list.
                table.insert(astrDeleteFiles, atData.strConfigurationPath)
                table.insert(astrDeleteFiles, atData.strConfigurationHashPath)
                table.insert(astrDeleteFiles, atData.strArtifactPath)
                table.insert(astrDeleteFiles, atData.strArtifactHashPath)
                -- Add the row ID to the list of SQL entries to delete.
                table.insert(aIdDeleteSql, atData.iId)
                -- Count the saved bytes.
                iBytesSaved = iBytesSaved + atData.iConfigurationSize + atData.iArtifactSize
                -- Saved already enough bytes?
                if iBytesSaved >= iBytesToSave then
                  break
                end
              end
            until atData==nil

            -- Close the cursor.
            tCursor:close()

            -- Found enough files?
            if iBytesSaved < iBytesToSave then
              self.tLogger:error('%s Failed to free %d bytes in the cache.', self.strLogID, iBytesToSave)
              tResult = nil
            else
              tResult = true

              -- Delete all SQL lines in the list.
              for _, iId in pairs(aIdDeleteSql) do
                self.tLogger:debug('%s Deleting SQL ID %d.', self.strLogID, iId)

                strQuery = string.format('DELETE FROM cache WHERE iId=%d', iId)
                local tSqlResult, strError = tSQLDatabase:execute(strQuery)
                if tSqlResult==nil then
                  self.tLogger:error('%s Failed to delete an entry in the cache: %s', self.strLogID, strError)
                  tResult = nil
                  break
                else
                  tSQLDatabase:commit()
                end
              end

              if tResult==true then
                -- Delete all files in the list.
                for _, strPath in pairs(astrDeleteFiles) do
                  self.tLogger:debug('%s Deleting "%s".', self.strLogID, strPath)

                  local tDeleteResult, strError = self.pl.file.delete(strPath)
                  if tDeleteResult~=true then
                    self.tLogger:error('%s Failed to remove file "%s": %s', self.strLogID, strPath, strError)
                    tResult = nil
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



--- Set the configuration of the cache instance.
-- @param strRepositoryRootPath The root path of the repository.
function Cache:configure(strRepositoryRootPath, ulMaximumSize)
  local tResult = nil


  self.tLogger:debug('%s Set the maximum size to %d bytes.', self.strLogID, ulMaximumSize)
  self.ulMaximumSize = ulMaximumSize

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
    -- Create the path template string.
    self.strPathTemplate = self.pl.path.join(strAbsRepositoryRootPath, '[group]/[module]/[version]/[artifact]-[version].[extension]')

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
      local strCreateStatement = 'CREATE TABLE cache (iId INTEGER PRIMARY KEY, strGroup TEXT NOT NULL, strModule TEXT NOT NULL, strArtifact TEXT NOT NULL, strVersion TEXT NOT NULL, strConfigurationPath TEXT NOT NULL, strConfigurationHashPath TEXT NOT NULL, iConfigurationSize INTEGER NOT NULL, strArtifactPath TEXT, strArtifactHashPath TEXT, iArtifactSize INTEGER, iCreateDate INTEGER NOT NULL, iLastUsedDate INTEGER NOT NULL)'
      local tTableResult = self:_sql_create_table(tSQLDatabase, 'cache', strCreateStatement)
      if tTableResult==nil then
        tSQLDatabase:close()
        self.tLogger:error('%s Failed to create the table.', self.strLogID)
      elseif tTableResult==true then
        self.tLogger:debug('%s Rebuild the cache information.', self.strLogID)
        tResult = self:_rebuild_complete_cache(tSQLDatabase)
        if tResult==true then
          tResult = self:_remove_odd_files(tSQLDatabase)
          if tResult==true then
            tResult = self:_enforce_maximum_size(tSQLDatabase, 0)
            if tResult~=true then
              self.tLogger:error('%s Failed to enforce the maximum size of the cache.', self.strLogID)
            end
          else
            self.tLogger:error('%s Failed to remove odd files from the cache.', self.strLogID)
          end
        else
          self.tLogger:error('%s Failed to rebuild the cache.', self.strLogID)
        end
      elseif tTableResult==false then
        -- The table already exists.
        tResult = true
      else
        self.tLogger:fatal('%s Invalid result from _sql_create_table!', self.strLogID)
      end

      if tResult==true then
        self.tSQLDatabase = tSQLDatabase
      end
    end
  end

  return tResult
end



function Cache:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local strError


  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- Search the artifact in the cache database.
  local fFound, atAttr = self:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  if fFound==nil then
    self.tLogger:error('%s Failed to search the cache.', self.strLogID)
    self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
  elseif fFound==false then
    self.tLogger:debug('%s The artifact %s is not in the cache.', self.strLogID, strGMAV)
    self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
  else
    self.tLogger:debug('%s Found the configuration for artifact %s in the cache.', self.strLogID, strGMAV)

    -- Read the contents of the configuration file.
    local strConfiguration
    strConfiguration, strError = self.pl.utils.readfile(atAttr.strConfigurationPath, true)
    if strConfiguration==nil then
      self.tLogger:error('%s Failed to read the configuration of artifact %s: %s', self.strLogID, strGMAV, strError)
      self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
    else
      -- Read the contents of the hash file.
      local strHash
      strHash, strError = self.pl.utils.readfile(atAttr.strConfigurationHashPath, false)
      if strHash==nil then
        self.tLogger:error('%s Failed to read the hash for the configuration of artifact %s: %s', self.strLogID, strGMAV, strError)
        self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
      else
        -- Verify the the hash.
        local fHashOk = self.hash:check_string(strConfiguration, strHash, atAttr.strConfigurationPath, atAttr.strConfigurationHashPath)
        if fHashOk~=true then
          self.tLogger:error('%s The hash of the configuration for artifact %s does not match the expected hash.', self.strLogID, strGMAV)
          self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
          -- FIXME: Check the hash in the cache itself. If it does not match too, remove the artifact from the cache.
        else
          -- Parse the configuration.
          local cA = self.ArtifactConfiguration(self.tLogger)
          local tParseResult = cA:parse_configuration(strConfiguration, atAttr.strConfigurationPath)
          if tParseResult==true then
            -- Compare the GMAV from the configuration with the requested values.
            local tCheckResult = cA:check_configuration(strGroup, strModule, strArtifact, tVersion)
            if tCheckResult~=true then
              self.tLogger:error('%s The configuration for artifact %s does not match the requested group/module/artifact/version.', self.strLogID, strGMAV)
              self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
              -- FIXME: Remove the artifact from the cache and run a complete rescan.
            else
              tResult = cA
              self.uiStatistics_RequestsConfigHit = self.uiStatistics_RequestsConfigHit + 1
              self.uiStatistics_ServedBytesConfig = self.uiStatistics_ServedBytesConfig + atAttr.iConfigurationSize
            end
          end
        end
      end
    end
  end

  return tResult
end



function Cache:get_artifact(cArtifact, strDestinationFolder)
  local tResult = nil


  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- Search the artifact in the cache database.
  local fFound, atAttr = self:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  if fFound==nil then
    self.tLogger:error('%s Failed to search the cache.', self.strLogID)
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  elseif fFound==false then
    self.tLogger:debug('%s The artifact %s is not in the cache.', self.strLogID, strGMAV)
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  elseif atAttr.strArtifactPath==nil then
    self.tLogger:debug('%s The cache entry for %s has only the configuration, but not the artifact.', self.strLogID, strGMAV)
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  else
    self.tLogger:debug('%s Found the artifact %s in the cache.', self.strLogID, strGMAV)

    -- Read the contents of the hash file.
    local strHash, strError = self.pl.utils.readfile(atAttr.strArtifactHashPath, false)
    if strHash==nil then
      self.tLogger:error('%s Failed to read the hash for the artifact %s: %s', self.strLogID, strGMAV, strError)
      self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
    else
      local strCachePath = atAttr.strArtifactPath

      -- Get the destination path.
      local _, strFileName = self.pl.path.splitpath(strCachePath)
      local strLocalPath = self.pl.path.join(strDestinationFolder, strFileName)

      -- Copy the file to the destination folder.
      local fCopyResult
      fCopyResult, strError = self.pl.file.copy(strCachePath, strLocalPath)
      if fCopyResult~=true then
        self.tLogger:error('%s Failed to copy the artifact to the depack folder: %s', self.strLogID, strError)
        self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
      else
        -- Verify the the artifact hash.
        -- NOTE: Do this in the depack folder.
        local fHashOk = self.hash:check_file(strLocalPath, strHash, atAttr.strArtifactHashPath)
        if fHashOk~=true then
          self.tLogger:error('%s The hash of the artifact %s in the depack folder does not match the expected hash.', self.strLogID, strGMAV)
          self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
          -- FIXME: Check the hash in the cache itself. If it does not match too, remove the artifact from the cache.
        else
          -- All OK, return the path of the artifact in the depack folder.
          tResult = strLocalPath
          self.uiStatistics_RequestsArtifactHit = self.uiStatistics_RequestsArtifactHit + 1
          self.uiStatistics_ServedBytesArtifact = self.uiStatistics_ServedBytesArtifact + atAttr.iArtifactSize
        end
      end
    end
  end

  return tResult
end



function Cache:add_configuration(cArtifact)
  local tResult = nil
  local strError

  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- First check if the artifact is not yet part of the cache.
  local fFound = self:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  if fFound==nil then
    self.tLogger:error('%s Failed to search the cache.', self.strLogID)
  elseif fFound==true then
    self.tLogger:debug('%s The artifact %s is already in the cache.', self.strLogID, strGMAV)
  else
    self.tLogger:debug('%s Adding the configuration for the artifact %s to the cache.', self.strLogID, strGMAV)

    tResult = self:_cachefs_write_configuration(cArtifact)
    if tResult==true then
      -- Add the configuration to the database.
      tResult = self:_database_add_configuration(self.tSQLDatabase, cArtifact)
    end
  end

  return tResult
end



function Cache:add_artifact(cArtifact, strArtifactSourcePath)
  local tResult = nil
  local strError

  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- First check if the artifact is not yet part of the cache.
  local fFound, atAttr = self:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  if fFound==nil then
    self.tLogger:error('%s Failed to search the cache.', self.strLogID)
  elseif fFound==true and atAttr.strArtifactPath~=nil then
    self.tLogger:debug('%s The artifact %s is already in the cache.', self.strLogID, strGMAV)
  else
    self.tLogger:debug('%s Adding the artifact %s to the cache.', self.strLogID, strGMAV)

    -- Add the artifact to the database.
    if atAttr==false then
      tResult = self:_cachefs_write_configuration(cArtifact)
      if tResult==true then
        tResult = self:_cachefs_write_artifact(cArtifact, strArtifactSourcePath)
        if tResult==true then
          -- Create a new entry.
          self:_database_add_artifact(self.tSQLDatabase, cArtifact)
        end
      end
    else
      -- Update an existing entry.
      tResult = self:_cachefs_write_artifact(cArtifact, strArtifactSourcePath)
      if tResult==true then
        self:_database_update_artifact(atAttr, cArtifact)
      end
    end
  end
end



function Cache:show_statistics(cReport)
  self.tLogger:info('%s Configuration requests: %d hit / %d miss / %d bytes served', self.strLogID, self.uiStatistics_RequestsConfigHit, self.uiStatistics_RequestsConfigMiss, self.uiStatistics_ServedBytesConfig)
  self.tLogger:info('%s Artifact requests: %d hit / %d miss / %d bytes served', self.strLogID, self.uiStatistics_RequestsArtifactHit, self.uiStatistics_RequestsArtifactMiss, self.uiStatistics_ServedBytesArtifact)

  cReport:addData(string.format('statistics/cache@id=%s/requests/configuration/hit', self.strID), self.uiStatistics_RequestsConfigHit)
  cReport:addData(string.format('statistics/cache@id=%s/requests/configuration/miss', self.strID), self.uiStatistics_RequestsConfigMiss)
  cReport:addData(string.format('statistics/cache@id=%s/served_bytes/configuration', self.strID), self.uiStatistics_ServedBytesConfig)
  cReport:addData(string.format('statistics/cache@id=%s/requests/artifact/hit', self.strID), self.uiStatistics_RequestsArtifactHit)
  cReport:addData(string.format('statistics/cache@id=%s/requests/artifact/miss', self.strID), self.uiStatistics_RequestsArtifactMiss)
  cReport:addData(string.format('statistics/cache@id=%s/served_bytes/artifact', self.strID), self.uiStatistics_ServedBytesArtifact)
end


return Cache
