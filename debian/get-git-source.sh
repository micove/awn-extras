#!/bin/sh

set -e

PACKAGE=awn-extras
giturl=https://github.com/p12tic/awn-extras.git
VER_SUFFIX=""

CWD_DIR=${PWD}
GOS_DIR=${CWD_DIR}/get-orig-source

DEB_SOURCE=$(dpkg-parsechangelog 2>/dev/null | sed -n 's/^Source: //p')
DEB_VERSION=$(dpkg-parsechangelog 2>/dev/null | sed -n 's/^Version: //p')
UPSTREAM_VERSION=$(echo ${DEB_VERSION} | sed -r 's/^[0-9]*://;s/-[^-]*$$//;s/\+dfsg[0-9]*$//')

if [ "${DEB_SOURCE}" != "${PACKAGE}" ]; then
	echo 'Please run this script from the sources root directory.'
	exit 1
fi

rm -rf ${GOS_DIR}
mkdir ${GOS_DIR} && cd ${GOS_DIR}

# Function declarations
gos_verify_version () {
	cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
	UPSTREAM_SHA1=$(git rev-parse --quiet --verify "${1}"^{commit} || true)
	if [ -z "${UPSTREAM_SHA1}" ]; then
		#Should only fail with stable releases. Retry with v${UPSTREAM_VERSION}
		UPSTREAM_SHA1=$(git rev-parse --quiet --verify "v${1}"^{commit} || true)
		if [ -z "${UPSTREAM_SHA1}" ]; then
			echo "Could not find upstream version ${1}."
		fi
	fi
}

gos_override_changelog_version () {
	if [ -z "${UPSTREAM_SHA1}" ]; then
		UPSTREAM_SHA1=master
	fi
	cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
	echo "Using git checkout ${UPSTREAM_SHA1}"
	# Rename directory since UPSTREAM_VERSION is invalid.
	git checkout ${UPSTREAM_SHA1}
	UPSTREAM_SHA1=$(git describe --tags | sed -e 's/v\(.*\)/\1/')
	if [ "${UPSTREAM_VERSION}" != "${UPSTREAM_SHA1}" ]; then
		cd ${GOS_DIR}
		mv ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION} ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_SHA1}
		UPSTREAM_VERSION=${UPSTREAM_SHA1}
	fi
}

gos_use_changelog_version () {
	cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
	echo "Using git checkout ${UPSTREAM_SHA1}"
	git checkout ${UPSTREAM_SHA1}
}

# Download sources
git clone --no-checkout ${giturl} ${DEB_SOURCE}-${UPSTREAM_VERSION}
if [ -z "${VER}" ]; then
	gos_verify_version ${UPSTREAM_VERSION}
	if [ -z "${UPSTREAM_SHA1}" ]; then
		gos_override_changelog_version
	else
		gos_use_changelog_version
	fi
else
	gos_verify_version ${VER}
	if [ -n "${UPSTREAM_SHA1}" ]; then
		echo "VER=${VER} maps to commit ${UPSTREAM_SHA1}"
	fi
	gos_override_changelog_version
fi

# Clean-up...
cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
find . -depth -type f -name ".gitignore" -exec rm -f '{}' \;
while read line; do rm -rf "$line"; done < ${CWD_DIR}/debian/get-orig-source-remove

# Setting times... (to make reproducible tarballs)
cd ${GOS_DIR}/${DEB_SOURCE}-${UPSTREAM_VERSION}
git ls-files -z  | xargs -0 -n100 -P2 sh -c 'for F; do
		if [ -e "$F" ]; then
			touch -h -d "$(git log -1 --format="%ai" -- "$F")" "$F"
		fi
	done' fnord
rm -rf .git*

# Packing...
cd ${GOS_DIR}
find -L ${DEB_SOURCE}-${UPSTREAM_VERSION} -xdev -type f -print | LC_ALL=C sort \
| XZ_OPT="-6v" tar -caf "${CWD_DIR}/${DEB_SOURCE}_${UPSTREAM_VERSION}${VER_SUFFIX}.orig.tar.xz" -T- --owner=root --group=root --mode=a+rX

cd ${CWD_DIR} && rm -rf ${GOS_DIR}
