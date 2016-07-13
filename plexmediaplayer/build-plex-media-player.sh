#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  Michael DeGuzis
# Git:	    	  https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  build-plex-media-player.sh
# Script Ver:	  0.5.5
# Description:	  Attempts to build a deb package from Plex Media Player git source
#                 PLEASE NOTE THIS SCRIPT IS NOT YET COMPLETE!
# See:		 
# Usage:
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

	# fallback to local repo pool target(s)
	REMOTE_USER="mikeyd"
	REMOTE_HOST="archboxmtd"
	REMOTE_PORT="22"

fi

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/steamos-tools/incoming"
	
fi

# reset source command for while loop
src_cmd=""

# upstream URL
git_url="https://github.com/plexinc/plex-media-player"
target="v1.1.2.359-2b757d45"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export USE_NETWORK="yes"
export STEAMOS_TOOLS_BETA_HOOK="true"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
pkgname="plex-media-player"
pkgver="1.1.2.359"
BUILDER="pdebuild"
export STEAMOS_TOOLS_BETA_HOOK="true"
pkgrev="1"
pkgsuffix="git+bsos"
DIST="brewmaster"
urgency="low"
maintainer="ProfessorKaos64"

# set build directories
export BUILD_DIR="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${BUILD_DIR}/${src_dir}"

install_prereqs()
{
	
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install needed packages from Debian repos
	sudo apt-get install -y --force-yes git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring ninja-build mesa-common-dev python-pkgconfig \
	libmpv-dev libsdl2-dev libcec-dev
	
	# built for Libregeek, specifically for this build
	sudo apt-get install -y --force-yes cmake mpv

}

main()
{

	#################################################
	# Fetch source
	#################################################

	# create and enter BUILD_DIR
	if [[ -d "${BUILD_DIR}" ]]; then

		sudo rm -rf "${BUILD_DIR}"
		mkdir -p "${BUILD_DIR}"

	else

		mkdir -p "${BUILD_DIR}"
	
	fi
	
	# Enter build dir
	cd "${BUILD_DIR}"
	
	# install prereqs for build
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi
	
	#################################################
	# Fetch PMP source
	#################################################
	
	echo -e "\n==> Obtaining upstream source code\n"
	
	git clone -b "${target}" "${git_url}" "${git_dir}"
	cd "${git_dir}"
	latest_commit=$(git log -n 1 --pretty=format:"%h")
	
	# Add extra files for orig tarball
	cp -r "${scriptdir}/plex-media-player.png" "${git_dir}"
	
	# enter git dir
	cd "${git_dir}"

	#################################################
	# Build PMP source
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	cd "${BUILD_DIR}"
	tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "${src_dir}"

	# copy in debian folder and other files
        cp -r "${scriptdir}/debian" "${git_dir}"

	# enter source dir
	cd "${git_dir}"

	commits_full=$(git log --pretty=format:"  * %cd %h %s")

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" --package \
		"${pkgname}" -D "${DIST}" -u "${urgency}" "Update to latest commit [${latest_commit}]"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" --package \
		"${pkgname}" -D "${DIST}" -u "${urgency}" "Initial upload"
		nano "debian/changelog"

	fi

	echo -e "\n==> Building Debian package from source\n"
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
			rsync -arv --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# Keep changelog
			cp "${git_dir}/debian/changelog" "${scriptdir}/debian/"
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main