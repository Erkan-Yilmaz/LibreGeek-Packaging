#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-openpht.sh
# Script Ver:	1.0.8
# Description:	Attempts to builad a deb package from latest plexhometheater
#		github release
#
# See:		https://github.com/RasPlex/OpenPHT
#		https://github.com/plexinc/plex-home-theater-public/blob/pht-frodo/README-BUILD-PLEX.md
#		https://forums.plex.tv/discussion/196117/linux-build#latest
#
# Track:	http://www.preining.info/blog/2015/05/plex-home-theater-1-4-1-for-debian-jessie-and-sid/
# Usage:	./build-openpht.sh
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

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming"
	
fi

# upstream vars
#git_url="https://github.com/plexinc/plex-home-theater-public"
#git_url="https://github.com/ProfessorKaos64/plex-home-theater-public"
git_url="https://github.com/RasPlex/OpenPHT"
#target="v1.6.0.113-46fadd5e"
target="1.6"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH="amd64"
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="true"		# requires cmake >= 3.1.0 (not in Jessie)
pkgname="openpht"
pkgver="1.6.2"
pkgrev="1"
pkgsuffix="${date_short}git+bsos"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
export build_dir="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${build_dir}/${src_dir}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s

	# install basic build packages
	sudo apt-get -y --force-yes install build-essential pkg-config bc \
	cmake debhelper cdbs unzip libboost-dev zip libgl1-mesa-dev libglu1-mesa-dev \
	libglew-dev libmad0-dev libjpeg-dev libsamplerate-dev libogg-dev libvorbis-dev \
	libfreetype6-dev libfontconfig-dev libbz2-dev libfribidi-dev libsqlite3-dev \
	libasound2-dev libpng12-dev libpcre3-dev liblzo2-dev libcdio-dev libsdl-dev \
	libsdl-image1.2-dev libsdl-mixer1.2-dev libenca-dev libjasper-dev libxt-dev \
	libxmu-dev libcurl4-gnutls-dev libdbus-1-dev libpulse-dev libavahi-common-dev \
	libavahi-client-dev libxrandr-dev libmpeg2-4-dev libass-dev libflac++-dev \
	libflac-dev zlib1g-dev libsmbclient-dev libiso9660-dev libssl-dev libvdpau-dev \
	libmicrohttpd-dev libmodplug-dev librtmp-dev curl libyajl-dev libboost-thread-dev \
	libboost-system-dev libplist-dev libcec-dev libudev-dev libshairport-dev libtiff5-dev \
	libtinyxml-dev libmp3lame-dev libva-dev yasm quilt

	# libcec
	sudo apt-get install -y --force-yes libcec3 dcadec1

}

main()
{

	# create build_dir
	if [[ -d "${build_dir}" ]]; then

		sudo rm -rf "${build_dir}"
		mkdir -p "${build_dir}"

	else

		mkdir -p "${build_dir}"

	fi

	# enter build dir
	cd "${build_dir}" || exit

	# install prereqs for build
	
	if [[ "${BUILDER}" != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs
	
	else
	
		# cdbs needed for build clean
		sudo apt-get install -y cdbs

	fi

	# Clone upstream source code and branch

	echo -e "\n==> Obtaining upstream source code\n"

	# clone
	git clone -b "${branch}" "${git_url}" "${git_dir}"

        # copy in debian folder and other files
        cp -r "$scriptdir/debian" "${git_dir}"
	
	# Trim out .git
	rm -rf "${git_dir}/.git"
	
	#################################################
	# Build package
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "${src_dir}"

	# enter source dir
	cd "${src_dir}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" \
		--package "${pkgname}" -D "${DIST}" -u "${urgency}" "Update build/release"
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}-${pkgrev}" \
		--package "${pkgname}" -D "${DIST}" -u "${urgency}" "Initial build"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	#  build
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
	
	Showing contents of: ${build_dir}
	
	EOF

	ls "${build_dir}" | grep -E "${pkgver}" 

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice

	if [[ "$transfer_choice" == "y" ]]; then

		# transfer files
		if [[ -d "${build_dir}" ]]; then
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
			--filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${build_dir}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

			# Keep changelog
			cp "${git_dir}/debian/changelog" "${scriptdir}/debian/"
		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
