#!/bin/sh

set -e

PACKAGE=awn-extras
bzrurl=lp:awn-extras
VER_SUFFIX=""

CWD_DIR=${PWD}
GOS_DIR=${CWD_DIR}/get-orig-source

DEB_SOURCE=$(dpkg-parsechangelog 2>/dev/null | sed -n 's/^Source: //p')
DEB_VERSION=$(dpkg-parsechangelog 2>/dev/null | sed -n 's/^Version: //p')
UPSTREAM_VERSION=$(echo ${DEB_VERSION} | sed -r 's/^[0-9]*://;s/-[^-]*$$//;s/\+dfsg[0-9]*$//')
BZR_REV=$(dpkg-parsechangelog 2>/dev/null | sed -rne 's,^Version: .*[+~]bzr([0-9]+).*,\1,p')

if [ "${DEB_SOURCE}" != "${PACKAGE}" ]; then
	echo 'Please run this script from the sources root directory.'
	exit 1
fi

rm -rf ${GOS_DIR}
mkdir ${GOS_DIR} && cd ${GOS_DIR}

# Download sources
bzr export -r ${BZR_REV} --per-file-timestamps ${DEB_SOURCE}-${UPSTREAM_VERSION} ${bzrurl}

# Clean-up...
cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
while read line; do rm -rf "$line"; done < ${CWD_DIR}/debian/get-orig-source-remove

# Setting times... (to make reproducible tarballs)
cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
BZR_TIME=$(bzr version-info -r ${BZR_REV} ${bzrurl} | sed -rne 's,^date: (.*),\1,p')
find . -type d | xargs -r touch -d "${BZR_TIME}"

# Packing...
cd ${GOS_DIR}
find -L ${DEB_SOURCE}-${UPSTREAM_VERSION} -xdev -type f -print | LC_ALL=C sort \
| XZ_OPT="-6v" tar -caf "${CWD_DIR}/${DEB_SOURCE}_${UPSTREAM_VERSION}${VER_SUFFIX}.orig.tar.xz" -T- --owner=root --group=root --mode=a+rX

cd ${CWD_DIR} && rm -rf ${GOS_DIR}
