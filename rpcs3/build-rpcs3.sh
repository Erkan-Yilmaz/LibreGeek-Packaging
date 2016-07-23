#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	build-rpcs3.sh
# Script Ver:	0.4.1
# Description:	Attempts to build a deb package from the latest rpcs3 source
#		code.
#
# See:		https://github.com/RPCS3/rpcs3
#
# Usage:	./build-rpcs3.sh
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
GIT_URL="https://github.com/RPCS3/rpcs3"
TARGET="master"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b --debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="true"
pkgver="0.0.0.9"
pkgname="rpcs3"
pkgrev="1"
# Base version sourced from ZIP file version
pkgsuffix="${date_short}git+bsos"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# Need network for pbuilder to pull down ut4 zip
export NETWORK="no"
# Use dirty hack to utilize ffmpeg-dev packages in our repo (only during build-time)
export APT_PREFS_HACK="true"

# set build directories
export BUILD_DIR="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
GIT_DIR="${BUILD_DIR}/${src_dir}"

# Compiler options
COMPILER="gcc"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config bc debhelper git-dch \
	libopenal-dev libwxgtk3.0-dev build-essential libglew-dev

}

main()
{

	# install prereqs for build
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi
	
	# If we are using gcc, it has to be 5.x
	# Currently (20160723), this is compiled manually into /opt/cross-gcc
	
	if [[ " ${COMPILER}" == "gcc" ]]; then

		if [[ ! -d "/opt/cross-gcc/bin/x86_64-linux-gnu-gcc" ]]; then

			echo -e "\nERROR: expected location for gcc not found!"
			exit 1

		fi
	
	fi

	echo -e "\n==> Obtaining upstream source code\n"

	# clone and get latest commit tag
	if [[ -d "${GIT_DIR}" || -f ${BUILD_DIR}/*.orig.tar.gz ]]; then

		echo -e "==Info==\nGit source files already exist! Remove and [r]eclone or [k]eep? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset RETRY flag
			RETRY="no"
			# clean and clone
			sudo rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}"
			git clone --recursive -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

		else

			# Unpack the original source later on for  clean RETRY
			# set RETRY flag
			RETRY="yes"

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# reset RETRY flag
			RETRY="no"
			# create and clone to current dir
			mkdir -p "${BUILD_DIR}" || exit 1
			git clone --recursive -b "${TARGET}" "${GIT_URL}" "${GIT_DIR}"

	fi

	# Source latest release version from .git?
	#release_tag=$(git describe --abbrev=0 --tags)
	# Set pkg version
	# pkgver="${release_tag}"
        
        # There are a LOT of submodules/history, trim them
        #echo -e "\nTrimming .git folders"
        #find "${GIT_DIR}" -name "*.git" -print0 | xargs -0 rm -rf

	# Add image to git dir
	# cp -r "${scriptdir}/rpcs3.png" "${GIT_DIR}"

	#################################################
	# Prepare sources
	#################################################

	cd "${BUILD_DIR}" || exit 1

	# create source tarball
	# For now, do not recreate the tarball if keep was used above (to keep it clean)
	# This way, we can try again with the orig source intact
	# Keep this method until a build is good to go, without error.
	
	if [[ "${RETRY}" == "no" ]]; then

		echo -e "\n==> Creating original tarball\n"
		sleep 2s
		tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "${src_dir}"
		
	else
	
		echo -e "\n==> Cleaning old source folders for RETRY"
		sleep 2s
		
		rm -rf *.dsc *.xz *.build *.changes ${GIT_DIR}
		mkdir -p "${GIT_DIR}"
	
		echo -e "\n==> RETRYing with prior source tarball\n"
		sleep 2s
		tar -xzf ${pkgname}_*.orig.tar.gz -C "${BUILD_DIR}" --totals
		sleep 2s

	fi

	# Add required files
	cp -r "${scriptdir}/debian" "${GIT_DIR}"

	#################################################
	# Build package
	#################################################

	# enter source dir
	cd "${GIT_DIR}"
	
	# Get latest commit and update submodules
	latest_commit=$(git log -n 1 --pretty=format:"%h")

	echo -e "\n==> Updating changelog"
	sleep 2s

	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" \
		--package "${pkgname}" -D "${DIST}" -u "${urgency}" "Update to the latest commit ${latest_commit}"
		nano "debian/changelog"
	
	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" \
		--package "${pkgname}" -D "${DIST}" -u "${urgency}" "Initial build"
		nano "debian/changelog"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	USENETWORK=$NETWORK DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

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


	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)

	# inform user of packages
	cat<<- EOF
	#################################################################
	If package was built without errors you will see it below.
	If you don't, please check build dependency errors listed above.
	#################################################################

	EOF

	echo -e "Showing contents of: ${BUILD_DIR}: \n"
	ls "${BUILD_DIR}" | grep -E *${pkgver}*

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		if [[ -d "${BUILD_DIR}" ]]; then

			# copy files to remote server
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}


			# uplaod local repo changelog
			cp "${GIT_DIR}/debian/changelog" "${scriptdir}/debian"

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
