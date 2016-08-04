#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-retroarch.sh
# Script Ver:	1.0.0
# Description:	Attempts to build a deb package from latest retroarch
#		github release
#
# See:		https://github.com/libretro/RetroArch
#
# Usage:	build-retroarch.sh
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


# Check if USER/HOST is setup under ~/.bashrc, set to default if blank
# This keeps the IP of the remote VPS out of the build script

if [[ "${REMOTE_USER}" == "" || "${REMOTE_HOST}" == "" ]]; then

	# fallback to local repo pool TARGET(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming_testing"

else

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming"

fi

# upstream vars
GIT_URL="https://github.com/libretro/RetroArch"
#TARGET="v1.3.4"

# Man page error in current release.
# Master is close enough, use that
TARGET="master"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS=""
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="retroarch"

PKGVER="1.3.6"
PKGREV="1"
PKGSUFFIX="git+bsos${PKGREV}"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_DIR
export BUILD_DIR="${HOME}/build-${PKGNAME}-temp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_DIR}/${SRCDIR}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config libpulse-dev\
	checkinstall bc build-essential devscripts make git-core curl libxxf86vm-dev\
	g++ pkg-config libglu1-mesa-dev freeglut3-dev mesa-common-dev lsb-release \
	libsdl1.2-dev libsdl-image1.2-dev libsdl-mixer1.2-dev libc6-dev x11proto-xext-dev \
	libsdl-ttf2.0-dev nvidia-cg-toolkit nvidia-cg-dev libasound2-dev unzip samba \
	smbclient libsdl2-dev libxml2-dev libavcodec-dev libfreetype6-dev libavformat-dev \
	libavutil-dev libswscale-dev libv4l-dev libdrm-dev libxinerama-dev libudev-dev \
	libusb-1.0-0-dev libxv-dev libopenal-dev libjack-jackd2-dev libgbm-dev \
	libegl1-mesa-dev python3-dev libavdevice-dev

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

	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# clone
	git clone -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

	# inject .desktop file (not found in release archives) and image
	cp -r "$scriptdir/retroarch.png" "${GIT_DIR}"
	cp -r "$scriptdir/retroarch.desktop" "${GIT_DIR}"
	
	###############################################################
	# correct any files needed here that you can ahead of time
	###############################################################

	# For whatever reason, some "defaults" don't quite work
	# Mayeb ship a config file in the future instead
	sed -ie 's|# assets_directory =|assets_directory = /usr/share/libretro/assets|' "${GIT_DIR}/retroarch.cfg"

	#################################################
	# Build package
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	cd "${BUILD_DIR}"
	tar -cvzf "${PKGNAME}_${PKGVER}.orig.tar.gz" "${SRCDIR}"

	# copy in debian folder
	cp -r "${scriptdir}/debian" "${GIT_DIR}"

	# enter source dir
	cd "${GIT_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
 	# Maybe include static message: "Update to release: ${TARGET}"
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${PKGVER}+${PKGSUFFIX}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${urgency}" "New release"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}+${PKGSUFFIX}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${urgency}" "Initial upload"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}
	
	#################################################
	# Cleanup
	#################################################
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"
	
	# inform user of packages
	cat<<- EOF 
	#################################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependency errors listed above.
	#################################################################

	EOF

	echo -e "Showing contents of: ${BUILD_DIR}: \n"
	ls "${BUILD_DIR}" | grep -E "${PKGVER}" 

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		if [[ -d "${BUILD_DIR}" ]]; then

			# copy files to remote server
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}


			# Only move the old changelog if transfer occurs to keep final changelog 
			# out of the picture until a confirmed build is made. Remove if upstream has their own.
			cp "${GIT_DIR}/debian/changelog" "${scriptdir}/debian"

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
