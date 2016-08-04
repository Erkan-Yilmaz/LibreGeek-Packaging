#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-mpv.sh
# Script Ver:	1.0.0
# Description:	Builds mpv for specific use in building PlexMediaPlayer
#
# See:		https://github.com/mpv-player/mpv
# Usage:        ./build-mpv.sh
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

# upstream URL
GIT_URL="https://github.com/mpv-player/mpv"
branch="v0.17.0"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b --debbuildopts -nc"
export STEAMOS_TOOLS_BETA_HOOK="true"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
PKGNAME="mpv"
BUILDER="pdebuild"
PKGVER="0.17.0"
PKGREV="2"
PKGSUFFIX="git+bsos${PKGREV}"
DIST="brewmaster"
urgency="low"
maintainer="ProfessorKaos64"

# set build directories
export BUILD_DIR="${HOME}/build-${PKGNAME}-temp"
SRCDIR="${PKGNAME}-${PKGVER}"
GIT_DIR="${BUILD_DIR}/${SRCDIR}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	
	# dependencies
	sudo apt-get install -y --force-yes build-essential git pkg-config samba-dev \
	luajit devscripts equivs ladspa-sdk libbluray-dev libbs2b-dev libcdio-paranoia-dev \
	libdvdnav-dev libdvdread-dev libenca-dev libfontconfig-dev libfribidi-dev libgme-dev \
	libgnutls28-dev libgsm1-dev libguess-dev libharfbuzz-dev libjack-jackd2-dev libopenjpeg-dev \
	liblcms2-dev liblircclient-dev liblua5.2-dev libmodplug-dev libmp3lame-dev libopenal-dev \
	libopus-dev libopencore-amrnb-dev libopencore-amrwb-dev librtmp-dev librubberband-dev \
	libschroedinger-dev libsmbclient-dev libssh-dev libsoxr-dev libspeex-dev libtheora-dev \
	libtool libtwolame-dev libuchardet-dev libv4l-dev libva-dev libvdpau-dev libvorbis-dev \
	libvo-aacenc-dev libvo-amrwbenc-dev libvpx-dev libwavpack-dev libx264-dev libxvidcore-dev \
	python-docutils rst2pdf yasm

}

main()
{
	
	# install prereqs for build

	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	else

		# required for dh_clean
		sudo apt-get install -y --force-yes pkg-kde-tools

	fi

	echo -e "\n==> Obtaining upstream source code\n"

	if [[ -d "${GIT_DIR}" || -f ${BUILD_DIR}/*.orig.tar.gz ]]; then

		echo -e "==Info==\nGit source files already exist! Remove and [r]eclone or [k]eep? ?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "r" ]]; then

			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# clean and clone
			sudo rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}"
			git clone -b "${branch}" "${GIT_URL}" "${GIT_DIR}"

		else

			# Unpack the original source later on for  clean retry
			# set retry flag
			retry="yes"

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# reset retry flag
			retry="no"
			# create and clone to current dir
			mkdir -p "${BUILD_DIR}" || exit 1
			git clone -b "${branch}" "${GIT_URL}" "${GIT_DIR}"

	fi

	#################################################
	# Prepare sources
	#################################################

	cd "${BUILD_DIR}" || exit 1

	# create source tarball
	# For now, do not recreate the tarball if keep was used above (to keep it clean)
	# This way, we can try again with the orig source intact
	# Keep this method until a build is good to go, without error.
	
	if [[ "${retry}" == "no" ]]; then

		echo -e "\n==> Creating original tarball\n"
		sleep 2s
		tar -cvzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" "${SRCDIR}"
		
	else
	
		echo -e "\n==> Cleaning old source folders for retry"
		sleep 2s
		
		rm -rf *.dsc *.xz *.build *.changes ${GIT_DIR}
		mkdir -p "${GIT_DIR}"
	
		echo -e "\n==> Retrying with prior source tarball\n"
		sleep 2s
		tar -xzf "${PKGNAME}_${PKGVER}+${PKGSUFFIX}.orig.tar.gz" -C "${BUILD_DIR}" --totals
		sleep 2s

	fi
	
	# add debian here, after unpack or creation
	cp -r "${scriptdir}/debian" "${GIT_DIR}"

	###############################################################
	# build package
	###############################################################

	# enter source dir
	cd "${GIT_DIR}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${urgency}" "Rebuild for newer FFMPEG in repository"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${PKGVER}+${PKGSUFFIX}-${PKGREV}" --package "${PKGNAME}" \
		-D "${DIST}" -u "${urgency}" "Initial upload"
		nano "debian/changelog"

	fi
	
	echo -e "\n==> Building Debian package from source\n"
	sleep 2s
	
	#################################################
	# Build mpv
	#################################################
	
	# build debian package
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

	ls "${BUILD_DIR}" | grep -E "${PKGVER}" 

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${BUILD_DIR}" ]]; then
			rsync -arv -e "ssh -p ${REMOTE_PORT}" --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# Keep changelog
			cp "${GIT_DIR}/debian/changelog" "${scriptdir}/debian/"
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
