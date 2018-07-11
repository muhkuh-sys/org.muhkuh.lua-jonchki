#! /bin/bash
set -e

# Check for all build dependencies.
declare -a -r astrDeb=(
	"lua5.1"
	"lua-sql-sqlite3"
	"lua-filesystem"
	"lua-expat"
	"p7zip-full"
	"xz-utils"
)
declare -a astrInstall=()
for strDeb in "${astrDeb[@]}"
do
	DPKG_STATUS=`dpkg-query -W -f='${Status}' ${strDeb} || echo 'unknown'`
	if [ "$DPKG_STATUS" != "install ok installed" ]; then
		astrInstall+=("${strDeb}")
	fi
done
if [ ${#astrInstall[@]} -gt 0 ]; then
	sudo apt-get update --assume-yes
	sudo apt-get install --assume-yes ${astrInstall[@]}
fi
