#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-retroarch-joypad-autoconfig.sh
# Script Ver:	1.0.0
# Description:	Attmpts to build a deb package from latest retroarch
#		github release
#
# See:		https://github.com/libretro/retroarch-joypad-autoconfig
#
# Usage:	build-retroarch-joypad-autoconfig.sh
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
GIT_URL="https://github.com/libretro/retroarch-joypad-autoconfig"
branch="master"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="false"
PKGNAME="retroarch-joypad-autoconfig"
epoch="1"
PKGVER="0.1.1"
PKGREV="1"
PKGSUFFIX="${date_short}git+bsos"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_TMP
export BUILD_TMP="${HOME}/build-${PKGNAME}-tmp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_TMP}/${SRCDIR}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config checkinstall bc \
	build-essential devscripts

}

main()
{

	# create BUILD_TMP
	if [[ -d "${BUILD_TMP}" ]]; then

		sudo rm -rf "${BUILD_TMP}"
		mkdir -p "${BUILD_TMP}"

	else

		mkdir -p "${BUILD_TMP}"

	fi

	# enter build dir
	cd "${BUILD_TMP}" || exit

	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# clone and checkout desired commit
	git clone -b "$branch" "$GIT_URL" "${GIT_DIR}"
	cd "${GIT_DIR}"
	latest_commit=$(git log -n 1 --pretty=format:"%h")
	git checkout $latest_commit 1> /dev/null

	#################################################
	# Build platform
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# enter build dir to create tarball
	cd "${BUILD_TMP}"

	# create source tarball
	tar -cvzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" "${SRCDIR}"

	# copy in debian folder
	cp -r "$scriptdir/debian" "${GIT_DIR}"

	###############################################################
	# correct any files needed here that you can ahead of time
	###############################################################

	# enter source dir
	cd "${SRCDIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${urgency}" "Update to the latest commit [${latest_commit}]"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${epoch}:${PKGVER}+${PKGSUFFIX}-${PKGREV}" \
		--package "${PKGNAME}" -D "${DIST}" -u "${urgency}" "Initial upload"
		nano "debian/changelog"

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

	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)

	# back out of build tmp to script dir if called from git clone
	if [[ "${scriptdir}" != "" ]]; then
		cd "${scriptdir}" || exit
	else
		cd "${HOME}" || exit
	fi

	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"

	echo -e "Showing contents of: ${BUILD_TMP}: \n"
	ls "${BUILD_TMP}" | grep -E "${PKGVER}"

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${BUILD_TMP}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_TMP}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			mv ${GIT_DIR}/debian/changelog ${scriptdir}/debian/
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main

