#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-platform.sh
# Script Ver:	0.5.7
# Description:	Attempts to build a deb package from platform git source
#
# See:		https://launchpadlibrarian.net/219136562/platform_2.19.3-1~vivid1.dsc
#
# Usage:	build-platform.sh [opts]
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

#################################################
# Set variables
#################################################

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

# repo destinatin vars (use only local hosts!)

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming"
	
fi

# upstream URL
git_url="https://github.com/Pulse-Eight/platform/"
branch="p8-platform-2.0.1"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="false"
pkgname="p8-platform"
pkgver="2.0.1"
pkgrev="2"
pkgsuffix="git+bsos${pkgrev}"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_DIR
export BUILD_DIR="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${BUILD_DIR}/${src_dir}"

install_prereqs()
{

	echo -e "\n==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config checkinstall bc python \
	cmake

}

main()
{
	
	# create BUILD_DIR
	if [[ -d "${BUILD_DIR}" ]]; then
	
		sudo rm -rf "${BUILD_DIR}"
		mkdir -p "${BUILD_DIR}"
		
	else
		
		mkdir -p "${BUILD_DIR}"
		
	fi

	# enter build dir
	cd "${BUILD_DIR}" || exit

	# install prereqs for build
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

	
	# Clone upstream source code
	
	echo -e "\n==> Obtaining upstream source code\n"

	git clone -b "${branch}" "${git_url}" "${git_dir}"
 
	#################################################
	# Build platform
	#################################################
	
	echo -e "\n==> Creating original tarball\n"
	sleep 2s
	
	# create source tarball
	cd "${BUILD_DIR}"
	tar -cvzf "${pkgname}_${pkgver}.orig.tar.gz" "${src_dir}"
	
	# emter source dir
	cd "${src_dir}"

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}" \
		"Update to the latest release, $pkgver"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}" --package "${pkgname}" -D "${DIST}" -u "${urgency}" \
		"Update to the latest release, $pkgver"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	# build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}
	
	#################################################
	# Cleanup
	#################################################
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# output finish
	cat<<-EOF
	
	Time started: ${time_stamp_start}
	echo -e "Time started: ${time_stamp_end}
	echo -e "Total Runtime (minutes): $runtime
	EOF
	
	# inform user of packages
	cat<<-EOF
	
	###############################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependcy errors listed above.
	###############################################################
	
	Showing contents of: ${BUILD_DIR}
	
	EOF

	ls "${BUILD_DIR}" | grep -E "${pkgver}" 

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${BUILD_DIR}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
