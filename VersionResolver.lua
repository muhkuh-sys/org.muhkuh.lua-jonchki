local version_resolver = {}


--- Convert a string to a positive integer.
-- This function converts one component of a version from a string to a number.
-- The components of a version are separated by dots ("."). One component must
-- be a positive integer.
-- @param strComponent The string to be converted.
-- @return The function returns 2 values. If an error occured, it returns false and an error message as a string.
--         If the function succeeded it returns true and the converted number.
function version_resolver:componentToNumber(strComponent)
	-- Expect success.
	local fOk = true

	-- This will be the number or the error message.
	local tResult = nil

	-- Try to convert the component to a number.
	local uiNumber = tonumber(strComponent)
	if uiNumber==nil then
		-- Failed to convert the component to a number.
		fOk = false
		tResult = string.format("Invalid version: '%s'. Component '%s' at offset %d is no number!", strVersion, strSub, iSearchPosition)
	elseif uiNumber<0 then
		-- The component is a negative number. This is invalid!
		fOk = false
		tResult = string.format("Invalid version: '%s'. Component '%s' at offset %d is negativ!", strVersion, strSub, iSearchPosition)
	else
		-- The component is a positive integer.
		tResult = uiNumber
	end

	return fOk, tResult
end



function version_resolver:splitString(strData, strSeparator)
	local fOk = true
	local tResult = nil
	local astrComponents = {}
	local iSearchPosition = 1


	repeat
		-- Find the next separator.
		local iStart,iEnd = string.find(strData, strSeparator, iSearchPosition, true)
		if iStart~=nil then
			-- There must be at least one char before the dot.
			if iSearchPosition==iStart then
				fOk = false
				tResult = string.format("Nothing before the separator at position %d!", iSearchPosition)
				break
			end
			-- Extract the string from the search start up to the separator.
			local strSub = string.sub(strData, iSearchPosition, iStart-1)
			table.insert(astrComponents, strSub)

			iSearchPosition = iEnd + 1
		end
	until iStart==nil

	if iSearchPosition>string.len(strData) then
		fOk = false
		tResult = "The string ends with a separator!"
	else
		local strSub = string.sub(strData, iSearchPosition)
		table.insert(astrComponents, strSub)
		tResult = astrComponents
	end

	return fOk, tResult
end



function version_resolver:convertStringToList(strVersion)
	local fOk = true
	local tResult = nil
	local auiComponents = {}


	-- Split the version string by dots.
	fOk,tResult = self:splitString(strVersion, ".")
	if fOk~=true then
		fOk = false
		tResult = string.format("Invalid version: '%s'. %s", strVersion, tResult)
	else
		local astrComponents = tResult

		-- Convert all components to numbers.
		for iCnt,strComponent in ipairs(astrComponents) do
			local uiNumber
			fOk,uiNumber = self:componentToNumber(strComponent)
			if fOk~=true then
				fOk = false
				tResult = uiNumber
				break
			else
				table.insert(auiComponents, uiNumber)
			end
		end
	end

	-- Does the list contain at least one version number?
	if table.maxn(auiComponents)==0 then
		fOk = false
		tResult = string.format("Invalid version: the string '%s' contains no version components.", strVersion)
	else
		tResult = auiComponents
	end

	return fOk, tResult
end



function version_resolver:getCleanString(strVersion)
	local fOk = true
	local tResult = nil


	fOk,tResult = self:convertStringToList(strVersion)
	if fOk==true then
		local strCleanVersion = table.concat(tResult, ".")
		tResult = strCleanVersion
	end

	return fOk, tResult
end



version_resolver.atMatchQuality = {}
version_resolver.atMatchQuality['EQUAL'] = 10                    -- Both versions are completely equal.
version_resolver.atMatchQuality['NOT_SPECIFIED_BELOW_MICRO'] = 9 -- The constraints do not specify version components below the micro component, but the version does.
version_resolver.atMatchQuality['DIFFERS_BELOW_MICRO'] = 8       -- The versions differ below the micro component.
version_resolver.atMatchQuality['NOT_SPECIFIED_MICRO'] = 7       -- The constraints do not specify the micro version, but the version does.
version_resolver.atMatchQuality['DIFFERS_MICRO'] = 6             -- The versions differ in the micro component.
version_resolver.atMatchQuality['NOT_SPECIFIED_MINOR'] = 5       -- The constraints do not specify the minor version, but the version does.
version_resolver.atMatchQuality['DIFFERS_MINOR'] = 4             -- The versions differ in the minor component.
version_resolver.atMatchQuality['NOT_SPECIFIED_MAJOR'] = 3       -- No constraints present.
version_resolver.atMatchQuality['DIFFERS_MAJOR'] = 2             -- The versions differ in the major component.



function version_resolver:compare(atVersionConstraints, atVersionTest)
	local iCompareResult = nil
	local iMatchQuality = nil

	-- Get the length of both versions.
	local uiVersionConstraintsLength = table.maxn(atVersionConstraints)
	local uiVersionTestLength = table.maxn(atVersionTest)

	-- If the constraints are empty, all versions match.
	if uiVersionConstraintsLength==0 then
		iCompareResult = 0
		iMatchQuality = self.atMatchQuality['NOT_SPECIFIED_MAJOR']
	else
		-- If the version is smaller than the constraints, fill it up with 0.
		if uiVersionTestLength<uiVersionConstraintsLength then
			-- Copy the old version to a new array.
			local atExtendedVersionTest = {}
			for iCnt=1,uiVersionTestLength do
				table.insert(atExtendedVersionTest, atVersionTest[iCnt])
			end
			-- Add 0 entries.
			for iCnt=uiVersionTestLength,uiVersionConstraintsLength do
				table.insert(atExtendedVersionTest, 0)
			end
			-- Replace the version information.
			atVersionTest = atExtendedVersionTest
			uiVersionTestLength = uiVersionConstraintsLength
		end

		-- Get the number of version components present in versions.
		local uiComponentsBothLength = math.min(uiVersionConstraintsLength, uiVersionTestLength)

		-- Compare each version component until a pair is not equal.
		local iCmp = 0
		local uiComponentPosition = 0
		for uiCnt=1,uiComponentsBothLength do
			uiComponentPosition = uiCnt
			iCmp = atVersionConstraints[uiCnt] - atVersionTest[uiCnt]
			if iCmp~=0 then
				-- The pair differs. Stop comparing.
				break
			end
		end

		-- Are all components equal?
		if iCmp==0 then
			-- All components up to now were equal.
			iCompareResult = 0

			-- Do both versions have the same length?
			if uiVersionConstraintsLength==uiVersionTestLength then
				-- Yes, all components are equal. This is a direct hit with the highest quality.
				iMatchQuality = self.atMatchQuality['EQUAL']
			else
				-- The constraints is smaller than the version.
				if uiVersionConstraintsLength==1 then
					iMatchQuality = self.atMatchQuality['NOT_SPECIFIED_MINOR']
				elseif uiVersionConstraintsLength==2 then
					iMatchQuality = self.atMatchQuality['NOT_SPECIFIED_MICRO']
				elseif uiVersionConstraintsLength>3 then
					iMatchQuality = self.atMatchQuality['NOT_SPECIFIED_BELOW_MICRO']
				else
					iMatchQuality = 0
				end
			end
		else
			-- Get the compare result. This is basically the sign of the components difference.
			if iCmp<0 then
				iCompareResult = -1
			else
				iCompareResult = 1
			end

			if uiComponentPosition==1 then
				iMatchQuality = self.atMatchQuality['DIFFERS_MAJOR']
			elseif uiComponentPosition==2 then
				iMatchQuality = self.atMatchQuality['DIFFERS_MINOR']
			elseif uiComponentPosition==3 then
				iMatchQuality = self.atMatchQuality['DIFFERS_MICRO']
			elseif uiComponentPosition>3 then
				iMatchQuality = self.atMatchQuality['DIFFERS_BELOW_MICRO']
			else
				iMatchQuality = 0
			end
		end
	end

	return iCompareResult,iMatchQuality
end



function version_resolver:getBestMatch(strVersionConstraint, astrVersions)
	local fOk = true
	local tResult = nil
	local atVersions = {}
	local astrMessages = {}
	local atBestMatches = {}


	print("constraint: " .. strVersionConstraint)
	print("versions: " .. table.concat(astrVersions, ", "))

	for iCnt,strVersion in ipairs(astrVersions) do
		-- Convert the version string into a table.
		fOk,tResult = self:convertStringToList(strVersion)
		if fOk~=true then
			break
		else
			table.insert(atVersions, tResult)
		end
	end

	if fOk==true then
		-- Are constraints specified?
		if string.len(strVersionConstraint)==0 then
			-- No constraints. Pick the highest version number.
			atBestMatches = atVersions
		else
			-- Convert the constrints srting to a version table.
			fOk,tResult = self:convertStringToList(strVersionConstraint)
			if fOk~=true then
				fOk = false
			else
				local atVersionConstraints = tResult

				-- Compare all versions to the constraint.
				local atMatchingVersions = {}
				for iCnt,atVersionTest in ipairs(atVersions) do
					local iCompareResult,iMatchQuality = self:compare(atVersionConstraints, atVersionTest)
					-- Sort out versions which differ in components.
					if iCompareResult~=0 then
						local strReason
						if iMatchQuality==self.atMatchQuality['DIFFERS_MAJOR'] then
							strReason = "The major version differs."
						elseif iMatchQuality==self.atMatchQuality['DIFFERS_MINOR'] then
							strReason = "The minor version differs."
						elseif iMatchQuality==self.atMatchQuality['DIFFERS_MICRO'] then
							strReason = "The micro version differs."
						elseif iMatchQuality==self.atMatchQuality['DIFFERS_BELOW_MICRO'] then
							strReason = "The version differs below the micro component."
						else
							strReason = "The version differs."
						end
						table.insert(astrMessages, string.format("Version '%s' not considered. %s", table.concat(atVersionTest, "."), strReason))
					else
						-- Add the good matches to the results.
						local atEntry = {}
						atEntry.tVersion = atVersionTest
						atEntry.iMatchQuality = iMatchQuality
						table.insert(atMatchingVersions, atEntry)
					end
				end

				-- Are there any matching versions?
				if table.maxn(atMatchingVersions)>0 then
					-- Yes, there are some matches.

					-- Find the highest quality.
					local iHighestQuality = 0
					for iCnt,atEntry in ipairs(atMatchingVersions) do
						if atEntry.iMatchQuality>iHighestQuality then
							iHighestQuality = atEntry.iMatchQuality
						end
					end
					table.insert(astrMessages, string.format("Best match quality is %d.", iHighestQuality))

					-- Discard all entries with a lower quality.
					for iCnt,atEntry in ipairs(atMatchingVersions) do
						if atEntry.iMatchQuality==iHighestQuality then
							table.insert(atBestMatches, atEntry.tVersion)
						else
							table.insert(astrMessages, string.format("Version '%s' not considered. Quality %d is too low.", table.concat(atEntry.tVersion, "."), atEntry.iMatchQuality))
						end
					end
				end
			end
		end

		if fOk==true then
			local uiMatches = table.maxn(atBestMatches)
			if uiMatches==0 then
				tResult = nil
			else
				local tHighestVersion = {0}

				-- Is more than one entry left?
				if uiMatches>1 then
					-- Convert the remaining versions to a string. This is only for the messages.
					local astrBestVersions = {}
					for iCnt,tVersion in ipairs(atBestMatches) do
						table.insert(astrBestVersions, table.concat(tVersion, "."))
					end
					local strBestVersions = table.concat(astrVersions, ", ")

					-- Get the highest version.
					local fFoundMatch = false
					for iCnt,tVersion in ipairs(atBestMatches) do
						local iCompareResult = self:compare(tVersion, tHighestVersion)
						if iCompareResult>0 then
							tHighestVersion = tVersion
							fFoundMatch = true
						end
					end

					if fFoundMatch~=true then
						fOk = false
						tResult = "Internal error, failed to pick the highest version number out of this list: " .. strBestVersions .. "."
					else
						table.insert(astrMessages, string.format("Picked version '%s' out of the list of best matches: %s", table.concat(tHighestVersion, "."), strBestVersions))
						tResult = tHighestVersion
					end
				else
					tHighestVersion = atBestMatches[1]
					table.insert(astrMessages, string.format("Picked version '%s'.", table.concat(tHighestVersion, ".")))
					tResult = tHighestVersion
				end
			end
		end
	end

	return fOk, tResult, astrMessages
end


return version_resolver
