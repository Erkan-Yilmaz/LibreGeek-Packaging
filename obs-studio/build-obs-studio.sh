#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-obs-studio.sh
# Script Ver:	1.0.0
# Description:	Attmpts to build a deb package from latest obs-studio
#		github release
#
# See:		https://github.com/jp9000/obs-studio
#
# Usage:	build-obs-studio.sh
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
GIT_URL="https://github.com/jp9000/obs-studio"
TARGET="0.15.2"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="obs-studio"
PKGVER="${TARGET}"
PKGREV="1"
PKGSUFFIX="git+bsos${PKGREV}"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_DIRECTORY
export BUILD_DIRECTORY="${HOME}/build-${PKGNAME}-tmp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_DIRECTORY}/${SRCDIR}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes libx11-dev libgl1-mesa-dev \
	libpulse-dev libxcomposite-dev libxinerama-dev libv4l-dev libudev-dev \
	libfreetype6-dev libfontconfig-dev qtbase5-dev libqt5x11extras5-dev \
	libx264-dev libxcb-xinerama0-dev libxcb-shm0-dev libjack-jackd2-dev \
	libcurl4-openssl-dev build-essential bc debhelper cdbs cmake libfdk-aac-dev

	echo -e "\n==> Installing $PKGNAME build dependencies...\n"
	sleep 2s

	# Until the ffmpeg build script is finished, install ffmpeg from rebuilt PPA source
	# hosted in the Libregeek repositories. Exit if not installed correctly.

	sudo apt-get install -y --force-yes ffmpeg libavcodec-ffmpeg-dev \
	libavdevice-ffmpeg-dev libavfilter-ffmpeg-dev libavformat-ffmpeg-dev \
	libavresample-ffmpeg-dev libavutil-ffmpeg-dev libpostproc-ffmpeg-dev \
	libswresample-ffmpeg-dev libswscale-ffmpeg-dev
}

main()
{

	# create BUILD_DIRECTORY
	if [[ -d "${BUILD_DIRECTORY}" ]]; then

		sudo rm -rf "${BUILD_DIRECTORY}"
		mkdir -p "${BUILD_DIRECTORY}"

	else

		mkdir -p "${BUILD_DIRECTORY}"

	fi

	# enter build dir
	cd "${BUILD_DIRECTORY}" || exit

	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	else

		# need cdbs before build for dh_clean
		sudo apt-get install -y --force-yes cdbs

	fi


	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# clone
	git clone -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

	#################################################
	# Build platform
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	cd "${BUILD_DIRECTORY}"
	tar -cvzf "${PKGNAME}_${PKGVER}.orig.tar.gz" "${SRCDIR}"

	# copy in debian folder
	cp -r "$scriptdir/debian" "${GIT_DIR}"

	# enter source dir
	cd "${SRCDIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${PKGVER}+${PKGSUFFIX}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${urgency}" "Update release"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}+${PKGSUFFIX}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${urgency}" "Update release"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${PKGNAME} from source\n"
	sleep 2s

	#  build
	DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)

	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

	# inform user of packages
	cat<<-EOF

	###############################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependcy errors listed above.
	###############################################################

	Showing contents of: ${BUILD_DIRECTORY}

	EOF

	ls "${BUILD_DIRECTORY}" | grep ${PKGVER}

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${BUILD_DIRECTORY}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIRECTORY}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# Keep changelog
			cp "${GIT_DIR}/debian/changelog" "${scriptdir}/debian/"
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
