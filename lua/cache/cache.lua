-- Create the cache class.
local class = require 'pl.class'
local Cache = class()


--- Initialize a new cache instance.
-- @param tLogger The logger object used for all kinds of messages.
-- @param strID The ID used in the the jonchkicfg.xml to reference this instance.
function Cache:_init(cLog, tPlatform, strID)
  local tLogWriter = require 'log.writer.prefix'.new(string.format('[Cache "%s"] ', strID), cLog)
  self.tLog = require "log".new(
    -- maximum log level
    "trace",
    tLogWriter,
    -- Formatter
    require "log.formatter.format".new()
  )

  self.tPlatform = tPlatform
  self.strRepositoryRootPath = nil
  self.strID = strID
  self.tSQLEnv = nil
  self.strDatabaseName = 'cache.sqlite3'

  -- The "penlight" module is always useful.
  self.pl = require'pl.import_into'()

  -- Get the hash abstraction.
  local cHash = require 'Hash'
  self.hash = cHash(cLog)

  self.ArtifactConfiguration = require 'ArtifactConfiguration'
  self.date = require 'date'
  self.sqlite3 = require 'luasql.sqlite3'
  self.Version = require 'Version'

  self.tLog.debug('Created cache.')

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
    self.tLog.error('Failed to query the last create statement for table "%s".', strTableName)
  else
    local strDatabaseCreateStatement = tCursor:fetch()
    tCursor:close()
    if strDatabaseCreateStatement==strCreateStatement then
      self.tLog.debug('The table structure for "%s" is up to date.', strTableName)
      self.tLog.debug('Create statement: "%s"', strCreateStatement)

      -- Do not create the table data from scratch.
      tResult = false
    elseif strDatabaseCreateStatement==nil then
      self.tLog.debug('The table "%s" does not exist yet. Create it now.', strTableName)
      self.tLog.debug('Create statement: "%s"', strCreateStatement)

      -- Create a new table.
      local tSqlResult, strError = tSQLCon:execute(strCreateStatement)
      if tSqlResult==nil then
        self.tLog.error('Failed to create the table "%s": %s', strTableName, strError)
      else
        tSQLCon:commit()

        -- Create the table data from scratch.
        tResult = true
      end
    else
      self.tLog.debug('The table "%s" has a different create statement. Delete and recreate it.', strTableName)
      self.tLog.debug('Old create statement: "%s"', strDatabaseCreateStatement)
      self.tLog.debug('New create statement: "%s"', strCreateStatement)

      -- Delete the old table.
      local tSqlResult, strError = tSQLCon:execute(string.format('DROP TABLE %s', strTableName))
      if tSqlResult==nil then
        self.tLog.error('Failed to delete the table "%s": %s', strTableName, strError)
      else
        tSQLCon:commit()

        -- Re-create a new table.
        local tSqlResult, strError = tSQLCon:execute(strCreateStatement)
        if tSqlResult==nil then
          self.tLog.error('Failed to re-create the table "%s": %s', strTableName, strError)
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



function Cache:_replace_path(cArtifact, strExtension)
  local tInfo = cArtifact.tInfo

  -- Convert the group to a list of folders.
  local strSlashGroup = self.pl.stringx.replace(tInfo.strGroup, '.', '/')

  -- Get the version string if there is a version object.
  local strVersion = nil
  if tInfo.tVersion~=nil then
    strVersion = tInfo.tVersion:get()
  end

  local strPlatform = ''
  if tInfo.strPlatform~='' then
    strPlatform = string.format('_%s', tInfo.strPlatform)
  end

  -- Construct the replace table.
  local atReplace = {
    ['dotgroup'] = tInfo.strGroup,
    ['group'] = strSlashGroup,
    ['module'] = tInfo.strModule,
    ['artifact'] = tInfo.strArtifact,
    ['version'] = strVersion,
    ['extension'] = strExtension,
    ['platform'] = strPlatform
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



-- Search for the GMAVP in the database.
-- @return nil for an error, false if nothing was found, a number on success.
function Cache:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strPlatform)
  local tResult = nil
  local atAttr = nil


  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLog.error('No connection to a database established.')
  else
    local strVersion = tVersion:get()
    local strQuery = string.format('SELECT * FROM cache WHERE strGroup="%s" AND strModule="%s" AND strArtifact="%s" AND strVersion="%s" AND strPlatform="%s"', strGroup, strModule, strArtifact, strVersion, strPlatform)
    local tCursor, strError = tSQLDatabase:execute(strQuery)
    if tCursor==nil then
      self.tLog.error('Failed to search the cache for an entry: %s', strError)
    else
      repeat
        local atData = tCursor:fetch({}, 'a')
        if atData~=nil then
          if atAttr~=nil then
            self.tLog.error('The cache database is broken. It has multiple entries for %s/%s/%s/%s/%s.', strGroup, strModule, strArtifact, strVersion, strPlatform)
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



-- Search for the GMAV with P=null in the database.
-- @return nil for an error, false if nothing was found, a number on success.
function Cache:_find_GMAVnull(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local atAttr = nil


  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLog.error('No connection to a database established.')
  else
    local strVersion = tVersion:get()
    local strQuery = string.format('SELECT * FROM cache WHERE strGroup="%s" AND strModule="%s" AND strArtifact="%s" AND strVersion="%s" AND strPlatform IS NULL', strGroup, strModule, strArtifact, strVersion)
    local tCursor, strError = tSQLDatabase:execute(strQuery)
    if tCursor==nil then
      self.tLog.error('Failed to search the cache for an entry: %s', strError)
    else
      repeat
        local atData = tCursor:fetch({}, 'a')
        if atData~=nil then
          if atAttr~=nil then
            self.tLog.error('The cache database is broken. It has multiple entries for %s/%s/%s/%s.', strGroup, strModule, strArtifact, strVersion)
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



function Cache:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  -- First try the platform independent package.
  local strCurrentPlatform = ''
  local fFound, atAttr = self:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform)
  if fFound==false then
    -- Try the platform specific package if the search was OK, but nothing was found.
    strCurrentPlatform = self.tPlatform:get_platform_id()
    fFound, atAttr = self:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform)
  end

  return fFound, atAttr, strCurrentPlatform
end



function Cache:_database_add_version(tSQLDatabase, strGroup, strModule, strArtifact, tVersion)
  local tResult = nil


  local strQuery = string.format('INSERT INTO cache (strGroup, strModule, strArtifact, strVersion, iCreateDate, iLastUsedDate) VALUES ("%s", "%s", "%s", "%s", strftime("%%s","now"), strftime("%%s","now"))', strGroup, strModule, strArtifact, tVersion:get())

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLog.error('Failed to add the new entry to the cache: %s', strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_add_configuration(tSQLDatabase, cArtifact, strSourceRepository)
  local tResult = nil


  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  local tInfo = cArtifact.tInfo
  local iConfigurationFileSize = self.pl.path.getsize(strPathConfiguration)

  local strQuery = string.format('INSERT INTO cache (strGroup, strModule, strArtifact, strVersion, strPlatform, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, strConfigurationSourceRepo, iCreateDate, iLastUsedDate) VALUES ("%s", "%s", "%s", "%s", "%s", "%s", "%s", %d, "%s", strftime("%%s","now"), strftime("%%s","now"))', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get(), tInfo.strPlatform, strPathConfiguration, strPathConfigurationHash, iConfigurationFileSize, strSourceRepository)

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLog.error('Failed to add the new entry to the cache: %s', strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_update_configuration(tSQLDatabase, iId, cArtifact, strSourceRepository)
  local tResult = nil


  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  local tInfo = cArtifact.tInfo
  local iConfigurationFileSize = self.pl.path.getsize(strPathConfiguration)

  local strQuery = string.format('UPDATE cache SET strPlatform="%s", strConfigurationPath="%s", strConfigurationHashPath="%s", iConfigurationSize=%d, strConfigurationSourceRepo="%s", iLastUsedDate=strftime("%%s","now") WHERE iId=%d', tInfo.strPlatform, strPathConfiguration, strPathConfigurationHash, iConfigurationFileSize, strSourceRepository, iId)

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLog.error('Failed to add the new entry to the cache: %s', strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_add_artifact(tSQLDatabase, cArtifact, strSourceRepository)
  local tResult = nil


  -- Get the paths.
  local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)
  local strPathConfiguration, strPathConfigurationHash = self:_get_configuration_paths(cArtifact)

  local tInfo = cArtifact.tInfo
  self.tLog.debug('Adding artifact %s/%s/%s V%s %s', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get(), tInfo.strPlatform)

  local iConfigurationFileSize = self.pl.path.getsize(strPathConfiguration)
  local iArtifactFileSize = self.pl.path.getsize(strPathArtifact)

  local strQuery = string.format('INSERT INTO cache (strGroup, strModule, strArtifact, strVersion, strPlatform, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, strConfigurationSourceRepo, strArtifactPath, strArtifactHashPath, iArtifactSize, strArtifactSourceRepo, iCreateDate, iLastUsedDate) VALUES ("%s", "%s", "%s", "%s", "%s", "%s", "%s", %d, "%s", "%s", %d, strftime("%%s","now"), strftime("%%s","now"))', tInfo.strGroup, tInfo.strModule, tInfo.strArtifact, tInfo.tVersion:get(), tInfo.strPlatform, strPathConfiguration, strPathConfigurationHash, iConfigurationFileSize, strSourceRepository, strPathArtifact, strPathArtifactHash, iArtifactFileSize, strSourceRepository)

  local tSqlResult, strError = tSQLDatabase:execute(strQuery)
  if tSqlResult==nil then
    self.tLog.error('Failed to add the new entry to the cache: %s', strError)
  else
    tSQLDatabase:commit()
    tResult = true
  end

  return tResult
end



function Cache:_database_update_artifact(atAttr, cArtifact, strSourceRepository)
  local tResult = nil


  -- Get the paths.
  local strPathArtifact, strPathArtifactHash = self:_get_artifact_paths(cArtifact)

  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLog.error('No connection to a database established.')
  else
    local iId = atAttr.iId
    local iArtifactFileSize = self.pl.path.getsize(strPathArtifact)

    local tInfo = cArtifact.tInfo

    local strQuery = string.format('UPDATE cache SET strPlatform="%s", strArtifactPath="%s", strArtifactHashPath="%s", iArtifactSize=%d, strArtifactSourceRepo="%s", iLastUsedDate=strftime("%%s","now") WHERE iId=%d', tInfo.strPlatform, strPathArtifact, strPathArtifactHash, iArtifactFileSize, strSourceRepository, iId)

    local tSqlResult, strError = tSQLDatabase:execute(strQuery)
    if tSqlResult==nil then
      self.tLog.error('Failed to update an entry in the cache: %s', strError)
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
      self.tLog.error('Failed to create the path "%s": %s', strPath, strError)
    end
  end

  if tResult==true then
    -- Write the configuration.
    self.tLog.debug('Write the configuration to %s.', strPathConfiguration)
    tResult, strError = self.pl.utils.writefile(strPathConfiguration, cArtifact.strSource, true)
    if tResult==nil then
      self.tLog.error('Failed to create the file for the configuration at "%s": %s', strPathConfiguration, strError)
    else
      -- Write the hash of the configuration.
      local strHash = self.hash:generate_hashes_for_string(cArtifact.strSource)
      self.tLog.debug('Write the configuration hash to %s.', strPathConfigurationHash)
      tResult, strError = self.pl.utils.writefile(strPathConfigurationHash, strHash, false)
      if tResult==nil then
        self.tLog.error('Failed to create the file for the configuration hash at "%s": %s', strPathConfigurationHash, strError)
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
      self.tLog.error('Failed to create the path "%s": %s', strPath, strError)
    end
  end

  if tResult==true then
    -- Copy the artifact.
    self.tLog.debug('Copy the artifact from %s to %s.', strArtifactSourcePath, strPathArtifact)
    tResult, strError = self.pl.file.copy(strArtifactSourcePath, strPathArtifact, true)
    if tResult~=true then
      self.tLog.error('Failed to copy the artifact from %s to %s: %s', strArtifactSourcePath, strPathArtifact, strError)
    else
      -- Create the hash for the artifact.
      -- NOTE: get the hash from the source file.
      tResult = self.hash:generate_hashes_for_file(strArtifactSourcePath)
      if tResult==nil then
        self.tLog.error('Failed to get the hash for "%s".', strArtifactSourcePath)
      else
        local strHash = tResult

        -- Write the hash of the artifact.
        self.tLog.debug('Write the artifact hash to %s.', strPathArtifactHash)
        tResult, strError = self.pl.utils.writefile(strPathArtifactHash, strHash, false)
        if tResult==nil then
          self.tLog.error('Failed to create the file for the artifact hash at "%s": %s', strPathArtifactHash, strError)
        end
      end
    end
  end

  return tResult
end



--- Remove files from the cache which do not belong there.
function Cache:_remove_odd_files(tSQLDatabase)
  -- Be optimistic.
  local tResult = true

  -- Get the full path of the SQLITE3 database file. This one should not be removed.
  local strDatabaseFilename = self.pl.path.join(self.strRepositoryRootPath, self.strDatabaseName)

  self.tLog.debug('Clean the cache by removing odd files from "%s".', self.strRepositoryRootPath)

  -- Loop over all files in the repository.
  for strRoot,astrDirs,astrFiles in self.pl.dir.walk(self.strRepositoryRootPath, false, true) do
    -- Loop over all files in the current directory.
    for _,strFile in pairs(astrFiles) do
      -- Get the full path of the file.
      local strFullPath = self.pl.path.join(strRoot, strFile)

      -- Keep the database file.
      if strFullPath==strDatabaseFilename then
        self.tLog.debug('Keeping database file "%s".', strDatabaseFilename)
      else
        -- Search the full path in the database.
        local strQuery = string.format('SELECT COUNT(*) FROM cache WHERE strConfigurationPath="%s" OR strConfigurationHashPath="%s" OR strArtifactPath="%s" OR strArtifactHashPath="%s"', strFullPath, strFullPath, strFullPath, strFullPath)
        local tCursor, strError = tSQLDatabase:execute(strQuery)
        if tCursor==nil then
          self.tLog.error('Failed to search the cache for an entry: %s', strError)
          tResult = nil
          break
        else
          local atData = tCursor:fetch({})
          if atData==nil then
            self.tLog.error('No result from database for query "%s".', strQuery)
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
              self.tLog.debug('Removing stray file "%s".', strFullPath)
              local tDeleteResult, strError = self.pl.file.delete(strFullPath)
              if tDeleteResult~=true then
                self.tLog.warning('Failed to remove stray file "%s": %s', strFullPath, strError)
              end
            elseif iCnt==1 then
              -- The path was found in the database.
            else
              self.tLog.error('Invalid result from database for query "%s": "%s"', strQuery, tostring(strResult))
              tResult = nil
              break
            end
          end
        end
      end
    end
  end

  self.tLog.debug('Finished cleaning the cache.')
  return tResult
end



function Cache:_enforce_maximum_size(tSQLDatabase, ulFreeSpaceNeeded)
  -- Be optimistic.
  local tResult = true

  local strQuery = string.format('SELECT TOTAL(iConfigurationSize)+TOTAL(iArtifactSize) FROM cache')
  local tCursor, strError = tSQLDatabase:execute(strQuery)
  if tCursor==nil then
    self.tLog.error('Failed to get the total size of the cache: %s', strError)
    tResult = nil
  else
    local atData = tCursor:fetch({})
    if atData==nil then
      self.tLog.error('No result from database for query "%s".', strQuery)
      tCursor:close()
      tResult = nil
    else
      -- Close the cursor.
      tCursor:close()

      local strResult = atData[1]
      local iTotalSize = tonumber(strResult)
      if iTotalSize==nil then
        self.tLog.error('Invalid result from database for query "%s": "%s"', strQuery, tostring(strResult))
        tResult = nil
      else
        self.tLog.debug('The total size of the cache is %d bytes.', iTotalSize)
        -- Check if the requested free space would grow the cache over the allowed maximum.
        local iBytesToSave = (iTotalSize + ulFreeSpaceNeeded) - self.ulMaximumSize
        if iBytesToSave>0 then
          self.tLog.debug('Need to shrink the cache by %d bytes.', iBytesToSave)

          -- Collect all files to delete in this table.
          local astrDeleteFiles = {}
          local aIdDeleteSql = {}
          local iBytesSaved = 0

          -- Loop over all artifacts starting with the oldest "last used" date.
          strQuery = string.format('SELECT iId, strConfigurationPath, strConfigurationHashPath, iConfigurationSize, strArtifactPath, strArtifactHashPath, iArtifactSize FROM cache ORDER BY iLastUsedDate ASC')
          tCursor, strError = tSQLDatabase:execute(strQuery)
          if tCursor==nil then
            self.tLog.error('Failed to get all cache entries: %s', strError)
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
              self.tLog.error('Failed to free %d bytes in the cache.', iBytesToSave)
              tResult = nil
            else
              tResult = true

              -- Delete all SQL lines in the list.
              for _, iId in pairs(aIdDeleteSql) do
                self.tLog.debug('Deleting SQL ID %d.', iId)

                strQuery = string.format('DELETE FROM cache WHERE iId=%d', iId)
                local tSqlResult, strError = tSQLDatabase:execute(strQuery)
                if tSqlResult==nil then
                  self.tLog.error('Failed to delete an entry in the cache: %s', strError)
                  tResult = nil
                  break
                else
                  tSQLDatabase:commit()
                end
              end

              if tResult==true then
                -- Delete all files in the list.
                for _, strPath in pairs(astrDeleteFiles) do
                  self.tLog.debug('Deleting "%s".', strPath)

                  local tDeleteResult, strError = self.pl.file.delete(strPath)
                  if tDeleteResult~=true then
                    self.tLog.error('Failed to remove file "%s": %s', strPath, strError)
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


  self.tLog.debug('Set the maximum size to %d bytes.', ulMaximumSize)
  self.ulMaximumSize = ulMaximumSize

  -- Convert this to an absolute path.
  local strAbsRepositoryRootPath = self.pl.path.abspath(strRepositoryRootPath)
  self.tLog.debug('Set the repository root path to "%s".', strAbsRepositoryRootPath)
  self.strRepositoryRootPath = strAbsRepositoryRootPath

  -- The path was already created by the system configuration.
  -- If it does not exist or it is no directory, this is an error.
  if self.pl.path.exists(strAbsRepositoryRootPath)~=strAbsRepositoryRootPath then
    self.tLog.error('The repository root path "%s" does not exist.', strAbsRepositoryRootPath)
  elseif self.pl.path.isdir(strAbsRepositoryRootPath)~=true then
    self.tLog.error('The repository root path "%s" is no directory.', strAbsRepositoryRootPath)
  else
    -- Create the path template string.
    self.strPathTemplate = self.pl.path.join(strAbsRepositoryRootPath, '[group]/[module]/[version]/[artifact]-[version][platform].[extension]')

    -- Append the database name to the path.
    local strDb = self.pl.path.join(strAbsRepositoryRootPath, self.strDatabaseName)

    -- Try to open an existing SQLite3 database in the root path.
    -- If the database does not exist yet, create it.
    self.tLog.debug('Opening database "%s".', strDb)
    local tSQLDatabase, strError = self.tSQLEnv:connect(strDb)
    if tSQLDatabase==nil then
      self.tLog.error('Failed to open the database "%s": %s', strDb, strError)
    else
      -- Construct the "CREATE" statement for the "cache" table.
      local strCreateStatement = 'CREATE TABLE cache (iId INTEGER PRIMARY KEY, strGroup TEXT NOT NULL, strModule TEXT NOT NULL, strArtifact TEXT NOT NULL, strVersion TEXT NOT NULL, strPlatform TEXT, strConfigurationPath TEXT, strConfigurationHashPath TEXT, iConfigurationSize INTEGER, strConfigurationSourceRepo TEXT, strArtifactPath TEXT, strArtifactHashPath TEXT, iArtifactSize INTEGER, strArtifactSourceRepo TEXT, iCreateDate INTEGER NOT NULL, iLastUsedDate INTEGER NOT NULL)'
      local tTableResult = self:_sql_create_table(tSQLDatabase, 'cache', strCreateStatement)
      if tTableResult==nil then
        tSQLDatabase:close()
        self.tLog.error('Failed to create the table.')
      elseif tTableResult==true then
        self.tLog.debug('Rebuild the cache information.')
        tResult = self:_remove_odd_files(tSQLDatabase)
        if tResult~=true then
          self.tLog.error('Failed to remove odd files from the cache.')
        else
          tResult = self:_enforce_maximum_size(tSQLDatabase, 0)
          if tResult~=true then
            self.tLog.error('Failed to enforce the maximum size of the cache.')
          end
        end
      elseif tTableResult==false then
        -- The table already exists.
        tResult = true
      else
        self.tLog.fatal('Invalid result from _sql_create_table!')
      end

      if tResult==true then
        strCreateStatement = 'CREATE TABLE scans (iId INTEGER PRIMARY KEY, strRemoteId TEXT NOT NULL, strGroup TEXT NOT NULL, strModule TEXT NOT NULL, strArtifact TEXT NOT NULL, iLastScan INTEGER NOT NULL)'
        tTableResult = self:_sql_create_table(tSQLDatabase, 'scans', strCreateStatement)
        if tTableResult==nil then
          tSQLDatabase:close()
          self.tLog.error('Failed to create the table.')
          tResult = nil
        elseif tTableResult~=true and tTableResult~=false then
          self.tLog.fatal('Invalid result from _sql_create_table!')
        end
      end

      if tResult==true then
        self.tSQLDatabase = tSQLDatabase
      end
    end
  end

  return tResult
end



function Cache:get_last_scan(strRemoteId, strGroup, strModule, strArtifact)
  local tResult
  local strQuery = string.format('SELECT iLastScan FROM scans WHERE strRemoteId="%s" AND strGroup="%s" AND strModule="%s" AND strArtifact="%s"', strRemoteId, strGroup, strModule, strArtifact)
  local tCursor, strError = self.tSQLDatabase:execute(strQuery)
  if tCursor==nil then
    self.tLog.error('Failed to search the scans for an entry: %s', strError)
  else
    local atAttr
    repeat
      local atData = tCursor:fetch({}, 'a')
      if atData~=nil then
        if atAttr~=nil then
          self.tLog.error('The scans database is broken. It has multiple entries for %s/%s/%s/%s.', strRemoteId, strGroup, strModule, strArtifact)
            -- TODO: remove all matching entries
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
      self.tLog.debug('No last scan found for %s/%s/%s/%s.', strRemoteId, strGroup, strModule, strArtifact)
      tResult = false
    else
      -- Exactly one match found. Return the ID.
      local iLastScan = atAttr.iLastScan
      self.tLog.debug('Found last scan for %s/%s/%s/%s: %d (now is %d).', strRemoteId, strGroup, strModule, strArtifact, iLastScan, os.time())
      tResult = iLastScan
    end
  end

  return tResult
end



function Cache:set_last_scan(strRemoteId, strGroup, strModule, strArtifact, iLastScan)
  local tResult = self:get_last_scan(strRemoteId, strGroup, strModule, strArtifact)
  if tResult~=nil then
    local strQuery
    if tResult==false then
      strQuery = string.format('INSERT INTO scans (strRemoteId, strGroup, strModule, strArtifact, iLastScan) VALUES ("%s", "%s", "%s", "%s", %d)', strRemoteId, strGroup, strModule, strArtifact, iLastScan)
    else
      strQuery = string.format('UPDATE scans SET iLastScan=%d WHERE strRemoteId="%s" AND strGroup="%s" AND strModule="%s" AND strArtifact="%s"', iLastScan, strRemoteId, strGroup, strModule, strArtifact)
    end

    local tSqlResult, strError = self.tSQLDatabase:execute(strQuery)
    if tSqlResult==nil then
      self.tLog.error('Failed to add the new entry to the cache: %s', strError)
      tResult = nil
    else
      self.tSQLDatabase:commit()
      self.tLog.debug('Set last scan for %s/%s/%s/%s to %d (now is %d).', strRemoteId, strGroup, strModule, strArtifact, iLastScan, os.time())
      tResult = true
    end
  end

  return tResult
end



function Cache:get_available_versions(strGroup, strModule, strArtifact)
  local tResult = nil


  local tSQLDatabase = self.tSQLDatabase
  if tSQLDatabase==nil then
    self.tLog.error('No connection to a database established.')
  else
    local strQuery = string.format('SELECT strVersion FROM cache WHERE strGroup="%s" AND strModule="%s" AND strArtifact="%s"', strGroup, strModule, strArtifact)
    local tCursor, strError = tSQLDatabase:execute(strQuery)
    if tCursor==nil then
      self.tLog.error('Failed to search the cache for an entry: %s', strError)
    else
      local atVersions = {}
      local atVersionExists = {}
      repeat
        local atData = tCursor:fetch({}, 'a')
        if atData~=nil then
          local tVersion = self.Version()
          local tVersionResult, strError = tVersion:set(atData.strVersion)
          if tVersionResult~=true then
            self.tLog.warning('Error in database: ignoring invalid "version" for %s/%s/%s: %s', strGroup, strModule, strArtifact, strError)
          else
            strVersion = tVersion:get()

            -- Do not add a version more than once.
            if atVersionExists[strVersion]==nil then
              table.insert(atVersions, tVersion)
              atVersionExists[strVersion] = true
            end
          end
        end
      until atData==nil

      -- Close the cursor.
      tCursor:close()

      tResult = atVersions
    end
  end

  return tResult
end



function Cache:get_configuration(strGroup, strModule, strArtifact, tVersion)
  local tResult = nil
  local strSourceID = nil
  local strError


  local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get())

  -- Search the artifact in the cache database. First try the PIP, then the PSP.
  local fFound, atAttr, strCurrentPlatform = self:_find_GMAV(strGroup, strModule, strArtifact, tVersion)
  if fFound==nil then
    self.tLog.error('Failed to search the cache.')
    self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
  elseif fFound==false then
    self.tLog.debug('The artifact %s is not in the cache.', strGMAV)
    self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
  elseif atAttr.strConfigurationPath==nil then
    self.tLog.debug('The cache entry does not have the configuration.', strGMAV)
    self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
  else
    self.tLog.debug('Found the configuration for artifact %s in the cache.', strGMAV)

    -- Read the contents of the configuration file.
    local strConfiguration
    strConfiguration, strError = self.pl.utils.readfile(atAttr.strConfigurationPath, true)
    if strConfiguration==nil then
      self.tLog.error('Failed to read the configuration of artifact %s: %s', strGMAV, strError)
      self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
    else
      -- Read the contents of the hash file.
      local strHash
      strHash, strError = self.pl.utils.readfile(atAttr.strConfigurationHashPath, false)
      if strHash==nil then
        self.tLog.error('Failed to read the hash for the configuration of artifact %s: %s', strGMAV, strError)
        self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
      else
        -- Verify the the hash.
        local fHashOk = self.hash:check_string(strConfiguration, strHash, atAttr.strConfigurationPath, atAttr.strConfigurationHashPath)
        if fHashOk~=true then
          self.tLog.error('The hash of the configuration for artifact %s does not match the expected hash.', strGMAV)
          self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
          -- FIXME: Check the hash in the cache itself. If it does not match too, remove the artifact from the cache.
        else
          -- Parse the configuration.
          local cA = self.ArtifactConfiguration(self.tLogger)
          local tParseResult = cA:parse_configuration(strConfiguration, atAttr.strConfigurationPath)
          if tParseResult==true then
            -- Compare the GMAV from the configuration with the requested values.
            local tCheckResult = cA:check_configuration(strGroup, strModule, strArtifact, tVersion, strCurrentPlatform)
            if tCheckResult~=true then
              self.tLog.error('The configuration for artifact %s does not match the requested group/module/artifact/version/platform.', strGMAV)
              self.uiStatistics_RequestsConfigMiss = self.uiStatistics_RequestsConfigMiss + 1
              -- FIXME: Remove the artifact from the cache and run a complete rescan.
            else
              tResult = cA
              strSourceID = atAttr.strConfigurationSourceRepo
              self.uiStatistics_RequestsConfigHit = self.uiStatistics_RequestsConfigHit + 1
              self.uiStatistics_ServedBytesConfig = self.uiStatistics_ServedBytesConfig + atAttr.iConfigurationSize
            end
          end
        end
      end
    end
  end

  return tResult, strSourceID
end



function Cache:get_artifact(cArtifact, strDestinationFolder)
  local tResult = nil
  local strSourceID = nil


  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strPlatform = tInfo.strPlatform
  local strGMAVP = string.format('%s/%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get(), strPlatform)

  -- Search the artifact in the cache database.
  -- Only look for the platform specified in the configuration "cArtifact".
  local fFound, atAttr = self:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strPlatform)
  if fFound==nil then
    self.tLog.error('Failed to search the cache.')
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  elseif fFound==false then
    self.tLog.debug('The artifact %s is not in the cache.', strGMAVP)
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  elseif atAttr.strArtifactPath==nil then
    self.tLog.debug('The cache entry does not have the artifact.', strGMAVP)
    self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
  else
    self.tLog.debug('Found the artifact %s in the cache.', strGMAVP)

    -- Read the contents of the hash file.
    local strHash, strError = self.pl.utils.readfile(atAttr.strArtifactHashPath, false)
    if strHash==nil then
      self.tLog.error('Failed to read the hash for the artifact %s: %s', strGMAVP, strError)
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
        self.tLog.error('Failed to copy the artifact to the depack folder: %s', strError)
        self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
      else
        -- Verify the the artifact hash.
        -- NOTE: Do this in the depack folder.
        local fHashOk = self.hash:check_file(strLocalPath, strHash, atAttr.strArtifactHashPath)
        if fHashOk~=true then
          self.tLog.error('The hash of the artifact %s in the depack folder does not match the expected hash.', strGMAV)
          self.uiStatistics_RequestsArtifactMiss = self.uiStatistics_RequestsArtifactMiss + 1
          -- FIXME: Check the hash in the cache itself. If it does not match too, remove the artifact from the cache.
        else
          -- All OK, return the path of the artifact in the depack folder.
          tResult = strLocalPath
          strSourceID = atAttr.strArtifactSourceRepo
          self.uiStatistics_RequestsArtifactHit = self.uiStatistics_RequestsArtifactHit + 1
          self.uiStatistics_ServedBytesArtifact = self.uiStatistics_ServedBytesArtifact + atAttr.iArtifactSize
        end
      end
    end
  end

  return tResult, strSourceID
end



function Cache:add_versions(strGroup, strModule, strArtifact, atNewVersions)
  local tResult = nil
  local strError

  local atExistingVersions = self:get_available_versions(strGroup, strModule, strArtifact)
  if atExistingVersions==nil then
    self.tLog.error('Failed to search the cache.')
  else
    -- Loop over all new versions.
    for _, tVersion in pairs(atNewVersions) do
      local strVersion = tVersion:get()
      local strGMAV = string.format('%s/%s/%s/%s', strGroup, strModule, strArtifact, strVersion)
      -- Check if the artifact is already in the cache.
      local fFound = false
      for _, tVersionCnt in pairs(atExistingVersions) do
        if tVersionCnt:get()==strVersion then
          fFound = true
          break
        end
      end
      if fFound==true then
        self.tLog.debug('The version of the artifact %s is already in the cache.', strGMAV)
      else
        self.tLog.debug('Adding the version for the artifact %s to the cache.', strGMAV)
        -- Add the version to the database.
        tResult = self:_database_add_version(self.tSQLDatabase, strGroup, strModule, strArtifact, tVersion)
        if tResult==nil then
          break
        end
      end
    end
  end

  return tResult
end



function Cache:add_configuration(cArtifact, strSourceRepository)
  local tResult = nil
  local strError

  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strPlatform = tInfo.strPlatform
  local strGMAVP = string.format('%s/%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get(), strPlatform)

  -- First check if the artifact with the requested platform is not yet part of the cache.
  local fFound, atAttr = self:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strPlatform)
  if fFound==false then
    -- Check if an entry with platform=NULL is present.
    fFound, atAttr = self:_find_GMAVnull(strGroup, strModule, strArtifact, tVersion)
  end

  if fFound==nil then
    self.tLog.error('Failed to search the cache.')
  elseif fFound==true then
    -- Found an entry in the cache.
    --  Does the entry have already a configuration path?
    if atAttr.strConfigurationPath==nil then
      self.tLog.debug('The the artifact %s is already in the cache, but it had no configuration.', strGMAVP)

      -- No configuration path yet. This is only a version entry.
      tResult = self:_cachefs_write_configuration(cArtifact)
      if tResult==true then
        self:_database_update_configuration(self.tSQLDatabase, atAttr.iId, cArtifact, strSourceRepository)
      end
    else
      self.tLog.debug('The configuration of the artifact %s is already in the cache.', strGMAVP)
    end
  else
    self.tLog.debug('Adding the configuration for the artifact %s to the cache.', strGMAVP)

    tResult = self:_cachefs_write_configuration(cArtifact)
    if tResult==true then
      -- Add the configuration to the database.
      tResult = self:_database_add_configuration(self.tSQLDatabase, cArtifact, strSourceRepository)
    end
  end

  return tResult
end



function Cache:add_artifact(cArtifact, strArtifactSourcePath, strSourceRepository)
  local tResult = nil
  local strError

  local tInfo = cArtifact.tInfo
  local strGroup = tInfo.strGroup
  local strModule = tInfo.strModule
  local strArtifact = tInfo.strArtifact
  local tVersion = tInfo.tVersion
  local strPlatform = tInfo.strPlatform
  local strGMAVP = string.format('%s/%s/%s/%s/%s', strGroup, strModule, strArtifact, tVersion:get(), strPlatform)

  -- First check if the artifact is not yet part of the cache.
  local fFound, atAttr = self:_find_GMAVP(strGroup, strModule, strArtifact, tVersion, strPlatform)
  if fFound==false then
    -- Check if an entry with platform=NULL is present.
    fFound, atAttr = self:_find_GMAVnull(strGroup, strModule, strArtifact, tVersion)
  end

  if fFound==nil then
    self.tLog.error('Failed to search the cache.')
  elseif fFound==true and atAttr.strArtifactPath~=nil then
    self.tLog.debug('The artifact %s is already in the cache.', strGMAVP)
  else
    self.tLog.debug('Adding the artifact %s to the cache.', strGMAVP)

    -- Add the artifact to the database.
    if atAttr==false then
      tResult = self:_cachefs_write_configuration(cArtifact)
      if tResult==true then
        tResult = self:_cachefs_write_artifact(cArtifact, strArtifactSourcePath)
        if tResult==true then
          -- Create a new entry.
          self:_database_add_artifact(self.tSQLDatabase, cArtifact, strSourceRepository)
        end
      end
    else
      -- Update an existing entry.
      tResult = self:_cachefs_write_artifact(cArtifact, strArtifactSourcePath)
      if tResult==true then
        self:_database_update_artifact(atAttr, cArtifact, strSourceRepository)
      end
    end
  end
end



function Cache:show_statistics(cReport)
  self.tLog.info('Configuration requests: %d hit / %d miss / %d bytes served', self.uiStatistics_RequestsConfigHit, self.uiStatistics_RequestsConfigMiss, self.uiStatistics_ServedBytesConfig)
  self.tLog.info('Artifact requests: %d hit / %d miss / %d bytes served', self.uiStatistics_RequestsArtifactHit, self.uiStatistics_RequestsArtifactMiss, self.uiStatistics_ServedBytesArtifact)

  cReport:addData(string.format('statistics/cache@id=%s/requests/configuration/hit', self.strID), self.uiStatistics_RequestsConfigHit)
  cReport:addData(string.format('statistics/cache@id=%s/requests/configuration/miss', self.strID), self.uiStatistics_RequestsConfigMiss)
  cReport:addData(string.format('statistics/cache@id=%s/served_bytes/configuration', self.strID), self.uiStatistics_ServedBytesConfig)
  cReport:addData(string.format('statistics/cache@id=%s/requests/artifact/hit', self.strID), self.uiStatistics_RequestsArtifactHit)
  cReport:addData(string.format('statistics/cache@id=%s/requests/artifact/miss', self.strID), self.uiStatistics_RequestsArtifactMiss)
  cReport:addData(string.format('statistics/cache@id=%s/served_bytes/artifact', self.strID), self.uiStatistics_ServedBytesArtifact)
end


return Cache
