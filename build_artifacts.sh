#! /bin/bash

# ----------------------------------------------------------------------------
#
# Try to get the VCS ID.
#
PROJECT_VERSION_VCS="unknown"
PROJECT_VERSION_VCS_LONG="unknown"
GIT_EXECUTABLE=$(which git)
STATUS=$?
if [ ${STATUS} -ne 0 ]
then
  echo "Git not found! Set the version to 'unknown'."
else
  GITV0=$(${GIT_EXECUTABLE} describe --abbrev=12 --always --dirty=+ --long)
  if [ ${STATUS} -ne 0 ]
  then
    echo "Failed to run Git! Set the version to 'unknown'."
  else
    if [[ ${GITV0} =~ ^[0-9a-f]+\+?$ ]]
    then
      echo 'This is a repository with no tags. Use the raw SHA sum.'
      PROJECT_VERSION_VCS="GIT${GITV0}"
      PROJECT_VERSION_VCS_LONG="GIT${GITV0}"
    elif [[ ${GITV0} =~ ^v([0-9.]+)-([0-9]+)-g([0-9a-f]+\+?)$ ]]
    then
      VCS_REVS_SINCE_TAG=${BASH_REMATCH[2]}
      if [ ${VCS_REVS_SINCE_TAG} -eq 0 ]
      then
        echo 'This is a repository which is exactly on a tag. Use the tag name.'
        PROJECT_VERSION_VCS="GIT${BASH_REMATCH[1]}"
        PROJECT_VERSION_VCS_LONG="GIT${BASH_REMATCH[1]}-${BASH_REMATCH[3]}"
      else
        echo 'This is a repository with commits after the last tag. Use the checkin ID.'
        PROJECT_VERSION_VCS="GIT${BASH_REMATCH[3]}"
        PROJECT_VERSION_VCS_LONG="GIT${BASH_REMATCH[3]}"
      fi
    else
      echo 'The description has an unknown format. Use the tag name.'
      PROJECT_VERSION_VCS="GIT${GITV0}"
      PROJECT_VERSION_VCS_LONG="GIT${GITV0}"
    fi
  fi
fi
echo "PROJECT_VERSION_VCS: ${PROJECT_VERSION_VCS}"
echo "PROJECT_VERSION_VCS_LONG: ${PROJECT_VERSION_VCS_LONG}"

# Errors are fatal from now on.
set -e

# Set the verbose level.
VERBOSE_LEVEL=debug

# Get the project folder.
PRJ_DIR=`pwd`

# This is the path to the jonchki tool.
JONCHKI_PATH=${PRJ_DIR}
JONCHKI=${JONCHKI_PATH}/jonchki.lua

# This is the base path where all packages will be assembled.
WORK_BASE=${PRJ_DIR}/targets/jonchki
mkdir -p ${WORK_BASE}

# Write the GIT version into the template.
rm -f ${WORK_BASE}/jonchki.xml
sed --expression="s/\${PROJECT_VERSION_VCS_LONG}/${PROJECT_VERSION_VCS_LONG}/" installer/jonchki_template.xml >${WORK_BASE}/jonchki.xml

# Remove all working folders and re-create them.
rm -rf ${WORK_BASE}/windows_32bit
rm -rf ${WORK_BASE}/windows_64bit
rm -rf ${WORK_BASE}/ubuntu_14.04_32bit
rm -rf ${WORK_BASE}/ubuntu_14.04_64bit
rm -rf ${WORK_BASE}/ubuntu_16.04_32bit
rm -rf ${WORK_BASE}/ubuntu_16.04_64bit
rm -rf ${WORK_BASE}/ubuntu_17.04_32bit
rm -rf ${WORK_BASE}/ubuntu_17.04_64bit
rm -rf ${WORK_BASE}/ubuntu_17.10_32bit
rm -rf ${WORK_BASE}/ubuntu_17.10_64bit

mkdir -p ${WORK_BASE}/windows_32bit
mkdir -p ${WORK_BASE}/windows_64bit
mkdir -p ${WORK_BASE}/ubuntu_14.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_14.04_64bit
mkdir -p ${WORK_BASE}/ubuntu_16.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_16.04_64bit
mkdir -p ${WORK_BASE}/ubuntu_17.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_17.04_64bit
mkdir -p ${WORK_BASE}/ubuntu_17.10_32bit
mkdir -p ${WORK_BASE}/ubuntu_17.10_64bit

# The common options are the same for all targets.
COMMON_OPTIONS="--syscfg ${PRJ_DIR}/installer/jonchkisys.cfg --prjcfg ${PRJ_DIR}/installer/jonchkicfg.xml --finalizer ${PRJ_DIR}/installer/finalizer.lua ${WORK_BASE}/jonchki.xml"

# Build the Windows_x86 artifact.
pushd ${WORK_BASE}/windows_32bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id windows --distribution-version "" --cpu-architecture x86 ${COMMON_OPTIONS}
popd
# Build the Windows_x86_64 artifact.
pushd ${WORK_BASE}/windows_64bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id windows --distribution-version "" --cpu-architecture x86_64 ${COMMON_OPTIONS}
popd

# Ubuntu 14.04 32bit
pushd ${WORK_BASE}/ubuntu_14.04_32bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 14.04 --cpu-architecture x86 ${COMMON_OPTIONS}
popd
# Ubuntu 14.04 64bit
pushd ${WORK_BASE}/ubuntu_14.04_64bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 14.04 --cpu-architecture x86_64 ${COMMON_OPTIONS}
popd

# Ubuntu 16.04 32bit
pushd ${WORK_BASE}/ubuntu_16.04_32bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 16.04 --cpu-architecture x86 ${COMMON_OPTIONS}
popd
# Ubuntu 16.04 64bit
pushd ${WORK_BASE}/ubuntu_16.04_64bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 16.04 --cpu-architecture x86_64 ${COMMON_OPTIONS}
popd

# Ubuntu 17.04 32bit
pushd ${WORK_BASE}/ubuntu_17.04_32bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 17.04 --cpu-architecture x86 ${COMMON_OPTIONS}
popd
# Ubuntu 17.04 64bit
pushd ${WORK_BASE}/ubuntu_17.04_64bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 17.04 --cpu-architecture x86_64 ${COMMON_OPTIONS}
popd

# Ubuntu 17.10 32bit
pushd ${WORK_BASE}/ubuntu_17.10_32bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 17.10 --cpu-architecture x86 ${COMMON_OPTIONS}
popd
# Ubuntu 17.10 64bit
pushd ${WORK_BASE}/ubuntu_17.10_64bit
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} -v ${VERBOSE_LEVEL} --distribution-id ubuntu --distribution-version 17.10 --cpu-architecture x86_64 ${COMMON_OPTIONS}
popd
