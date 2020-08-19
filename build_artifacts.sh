#! /bin/bash

# Check the number of parameters.
if [ $# -ne 3 ]
then
  echo "The script needs 3 parameter:"
  echo "  1) the distribution ID"
  echo "  2) the distribution version (can be an empty string '')"
  echo "  3) the CPU architecture"
  exit -1
fi

JONCHKI_DISTRIBUTION_ID=$1
JONCHKI_DISTRIBUTION_VERSION=$2
JONCHKI_CPU_ARCHITECTURE=$3

if [ "${JONCHKI_DISTRIBUTION_VERSION}" == "" ]
then
  JONCHKI_PLATFORM_ID="${JONCHKI_DISTRIBUTION_ID}_${JONCHKI_CPU_ARCHITECTURE}"
else
  JONCHKI_PLATFORM_ID="${JONCHKI_DISTRIBUTION_ID}_${JONCHKI_DISTRIBUTION_VERSION}_${JONCHKI_CPU_ARCHITECTURE}"
fi
echo "Building jonchki for ${JONCHKI_PLATFORM_ID}"


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

# This is the working folder for the current platform.
WORK=${WORK_BASE}/${JONCHKI_PLATFORM_ID}

# Write the GIT version into the template.
rm -f ${WORK_BASE}/jonchki.xml
sed --expression="s/\${PROJECT_VERSION_VCS_LONG}/${PROJECT_VERSION_VCS_LONG}/" installer/jonchki_template.xml >${WORK_BASE}/jonchki.xml

# Remove the working folder and re-create it.
rm -rf ${WORK}
mkdir -p ${WORK}

# The common options are the same for all targets.
COMMON_OPTIONS="--syscfg ${PRJ_DIR}/installer/jonchkisys.cfg --prjcfg ${PRJ_DIR}/installer/jonchkicfg.xml --finalizer ${PRJ_DIR}/installer/finalizer.lua --dependency-log ${PRJ_DIR}/dependency-log.xml ${WORK_BASE}/jonchki.xml"

# Build the artifact.
pushd ${WORK}
LD_LIBRARY_PATH=${JONCHKI_PATH} ${JONCHKI_PATH}/lua5.1 ${JONCHKI} install-dependencies -v ${VERBOSE_LEVEL} --distribution-id "${JONCHKI_DISTRIBUTION_ID}" --distribution-version "${JONCHKI_DISTRIBUTION_VERSION}" --cpu-architecture "${JONCHKI_CPU_ARCHITECTURE}" ${COMMON_OPTIONS}
popd
