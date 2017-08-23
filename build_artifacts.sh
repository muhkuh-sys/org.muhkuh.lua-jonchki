#! /bin/bash
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

# Remove all working folders and re-create them.
rm -rf ${WORK_BASE}/windows_32bit
rm -rf ${WORK_BASE}/windows_64bit
rm -rf ${WORK_BASE}/ubuntu_14.04_32bit
rm -rf ${WORK_BASE}/ubuntu_14.04_64bit
rm -rf ${WORK_BASE}/ubuntu_16.04_32bit
rm -rf ${WORK_BASE}/ubuntu_16.04_64bit
rm -rf ${WORK_BASE}/ubuntu_17.04_32bit
rm -rf ${WORK_BASE}/ubuntu_17.04_64bit

mkdir -p ${WORK_BASE}/windows_32bit
mkdir -p ${WORK_BASE}/windows_64bit
mkdir -p ${WORK_BASE}/ubuntu_14.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_14.04_64bit
mkdir -p ${WORK_BASE}/ubuntu_16.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_16.04_64bit
mkdir -p ${WORK_BASE}/ubuntu_17.04_32bit
mkdir -p ${WORK_BASE}/ubuntu_17.04_64bit

# The common options are the same for all targets.
COMMON_OPTIONS="--syscfg ${PRJ_DIR}/installer/jonchkisys.cfg --prjcfg ${PRJ_DIR}/installer/jonchkicfg.xml --finalizer ${PRJ_DIR}/installer/finalizer.lua ${PRJ_DIR}/installer/jonchki.xml"

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
