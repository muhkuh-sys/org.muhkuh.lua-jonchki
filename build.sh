#! /bin/bash

OVERRIDE_CONFIG=~/.mbs2/overrides.cfg
if [ -f "$OVERRIDE_CONFIG" ]; then
    . $OVERRIDE_CONFIG
fi

# FIXME: Get this from a config file.
JONCHKI_VERSION=0.0.12.1
JONCHKI_VERBOSE=debug
JONCHKI_REPOSITORY=~/.mbs2
JONCHKI_SYSCFG=jonchki/jonchkisys.cfg
JONCHKI_PRJCFG=jonchki/jonchkicfg.xml
JONCHKI_DEPENDENCY_LOG=dependency-log.xml
JONCHKI_LOG=

# ---------------------------------------------------------------------------
#
# Get the host architecture.
#

# Get the CPU architecture with the "lscpu" command.
CPUARCH=$(lscpu | awk -F'Architecture:' '{print $2}' | xargs)
# Translate a few older CPUs to a (hopefully) compatible architecture.
declare -A arch2bits=(
  ["i386"]="x86"
  ["i486"]="x86"
  ["i586"]="x86"
  ["i686"]="x86"
)
HOST_ARCHITECTURE="${arch2bits[$CPUARCH]}"
if [ -z "${HOST_ARCHITECTURE}" ]; then
  HOST_ARCHITECTURE=$CPUARCH
fi

# Detect a 32 bit system running on a 64bit CPU.
OSARCH=$(getconf LONG_BIT)
if [ "$OSARCH" == "32" ]; then
  # This is an x86_64 CPU running a x86 OS.
  if [ "$HOST_ARCHITECTURE" == "x86_64" ]; then
    HOST_ARCHITECTURE="x86"
  fi
fi

if [ -z "${HOST_ARCHITECTURE}" ]; then
  echo "Failed to detect the host architecture."
  exit -1
fi

# ---------------------------------------------------------------------------
#
# Get the OS.
#

if [ -f /etc/lsb-release ]; then
  HOST_DISTRIBUTION_ID=$(cat /etc/lsb-release | awk -F'DISTRIB_ID=' '{print $2}' | xargs | awk '{print tolower($0)}')
  HOST_DISTRIBUTION_VERSION=$(cat /etc/lsb-release | awk -F'DISTRIB_RELEASE=' '{print $2}' | xargs)
fi

if [ -z "${HOST_DISTRIBUTION_ID}" ]; then
  echo "Failed to detect the distribution ID."
  exit -1
fi
if [ -z "${HOST_DISTRIBUTION_VERSION}" ]; then
  echo "Failed to detect the distribution version."
  exit -1
fi

# ---------------------------------------------------------------------------
#
# Apply overrides.
#
if [ -n "$HOST_DISTRIBUTION_ID_OVERRIDE" ]; then
    echo "Overriding the host distribution ID for MBS from $HOST_DISTRIBUTION_ID to $HOST_DISTRIBUTION_ID_OVERRIDE ."
    HOST_DISTRIBUTION_ID=$HOST_DISTRIBUTION_ID_OVERRIDE
fi
if [ -n "$HOST_DISTRIBUTION_VERSION_OVERRIDE" ]; then
    echo "Overriding the host distribution version for MBS from $HOST_DISTRIBUTION_VERSION to $HOST_DISTRIBUTION_VERSION_OVERRIDE ."
    HOST_DISTRIBUTION_VERSION=$HOST_DISTRIBUTION_VERSION_OVERRIDE
fi
if [ -n "$HOST_ARCHITECTURE_OVERRIDE" ]; then
    echo "Overriding the host architecture for MBS from $HOST_ARCHITECTURE to $HOST_ARCHITECTURE_OVERRIDE ."
    HOST_ARCHITECTURE=$HOST_ARCHITECTURE_OVERRIDE
fi

# ---------------------------------------------------------------------------
#
# Get the standard archive format.
#

declare -A distribid2archformat=(
  ["ubuntu"]="tar.gz"
)
STANDARD_ARCHIVE_FORMAT="${distribid2archformat[$HOST_DISTRIBUTION_ID]}"

if [ -z "${STANDARD_ARCHIVE_FORMAT}" ]; then
  echo "Failed to detect the standard archive format."
  exit -1
fi

# ---------------------------------------------------------------------------

ARTIFACT_FILE="jonchki-${JONCHKI_VERSION}-${HOST_DISTRIBUTION_ID}${HOST_DISTRIBUTION_VERSION}_${HOST_ARCHITECTURE}.${STANDARD_ARCHIVE_FORMAT}"

# Get the path to the artifact download and depack folder.
ARTIFACT_REPOSITORY_PATH=$(realpath ${JONCHKI_REPOSITORY})/repository/org/muhkuh/lua/jonchki/${JONCHKI_VERSION}
ARTIFACT_INSTALL_PATH=$(realpath ${JONCHKI_REPOSITORY})/install/org/muhkuh/lua/jonchki
JONCHKI_TOOL=${ARTIFACT_INSTALL_PATH}/jonchki-${JONCHKI_VERSION}/jonchki

# Create the paths if they does not exist.
mkdir -p ${ARTIFACT_REPOSITORY_PATH}
if [ $? -ne 0 ]; then
  echo "Failed to create the repository path \"${ARTIFACT_REPOSITORY_PATH}\"."
  exit -1
fi
mkdir -p ${ARTIFACT_INSTALL_PATH}
if [ $? -ne 0 ]; then
  echo "Failed to create the install path \"${ARTIFACT_INSTALL_PATH}\"."
  exit -1
fi

# Was the artifact already downloaded?
if [ ! -f "${ARTIFACT_REPOSITORY_PATH}/${ARTIFACT_FILE}" ]; then
  echo "Downloading the artifact..."
  curl --location --output ${ARTIFACT_REPOSITORY_PATH}/${ARTIFACT_FILE} https://github.com/muhkuh-sys/org.muhkuh.lua-jonchki/releases/download/v${JONCHKI_VERSION}/${ARTIFACT_FILE}
  if [ $? -ne 0 ]; then
    echo "Failed to download the artifact."
    exit -1
  fi
fi

# Was the artifact already depacked?
if [ ! -f "${JONCHKI_TOOL}" ]; then
  if [ "${STANDARD_ARCHIVE_FORMAT}" == "tar.gz" ]; then
    tar --directory=${ARTIFACT_INSTALL_PATH} --file=${ARTIFACT_REPOSITORY_PATH}/${ARTIFACT_FILE} --extract --gzip
    if [ $? -ne 0 ]; then
      echo "Failed to extract the artifact ${ARTIFACT_REPOSITORY_PATH}/${ARTIFACT_FILE} ."
      exit -1
    fi
  else
    echo "Unknown archive format: ${STANDARD_ARCHIVE_FORMAT}"
    exit -1
  fi
fi

# Get the version of the installed tool.
INSTALLED_JONCHKI_VERSION=$(${JONCHKI_TOOL} --version | cut --delimiter=" " --fields=2 | awk '{print tolower($0)}')
if [ "${INSTALLED_JONCHKI_VERSION}" != "v${JONCHKI_VERSION}" ]; then
  echo "Unexpected jonchki version in \"${JONCHKI_TOOL}\", expected \"v${JONCHKI_VERSION}\", found \"${INSTALLED_JONCHKI_VERSION}\"."
fi

# Run jonchki.
${JONCHKI_TOOL} build
if [ $? -ne 0 ]; then
  exit -1
fi
