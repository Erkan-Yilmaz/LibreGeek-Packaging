#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	build-darkmod.sh
# Script Ver:	0.6.1
# Description:	Attempts to build a deb package from the laest "The Dark Mod"
#		release. This is more of a virtual package that deploys and updater
#		Which is run post-install.
#
# See:		https://github.com/ProfessorKaos64/tdm
#		http://wiki.darkmod.com/index.php?title=The_Dark_Mod_-_Compilation_Guide
#		http://wiki.darkmod.com/index.php?title=DarkRadiant_-_Compiling_in_Linux
#
# Usage:	./build-darkmod.sh
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
# upstream vars
#git_url="https://github.com/ProfessorKaos64/tdm"
#branch="master"

# package vars
date_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
date_short=$(date +%Y%m%d)
ARCH=""
BUILDER="pdebuild"
BUILDOPTS="--debbuildopts -b"
export STEAMOS_TOOLS_BETA_HOOK="false"
# required to run postinstall
USENETWORK="yes"
pkgname="darkmod"
pkgver="2.0.4"
pkgrev="1"
upstream_rev="1"
pkgsuffix="git+bsos${pkgrev}"
DIST="brewmaster"
urgency="low"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set BUILD_DIRs
export BUILD_DIR="${HOME}/build-${pkgname}-temp"
src_dir="${pkgname}-${pkgver}"
git_dir="${BUILD_DIR}/${src_dir}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config bc debhelper gcc g++ \
	g++-4.9-multilib m4 zip libglew-dev libglew-dev:i386 libpng12-dev libpng12-dev:i386 \
	libjpeg62-dev libjpeg62-dev:i386 libc6-dev:i386 libxxf86vm-dev libxxf86vm-dev:i386 \
	libopenal-dev libopenal-dev:i386 libasound2-dev libasound2-dev:i386 libxext-dev \
	libxext-dev:i386 scons

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
	# NOTE! - If you wish to source versions or commits automatically into variables here,
	# 	  such as commits, of upstream tags, see docs/pkg-versioning.md

	echo -e "\n==> Obtaining upstream source code\n"

	######## Use a virtual package for now ########
	mkdir -p "${git_dir}"
	cp -r "${scriptdir}/darkmod.png" "${git_dir}"
	cp -r "${scriptdir}/darklauncher.sh" "${git_dir}/darklauncher"
	cp -r "${scriptdir}/darkmod-updater.sh" "${git_dir}"

	#################################################
	# Build package
	#################################################

	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	# create source tarball
	cd "${BUILD_DIR}" || exit
	tar -cvzf "${pkgname}_${pkgver}+${pkgsuffix}.orig.tar.gz" "${src_dir}"

	# Add debian folder for current virtual package implementation
	cp -r "${scriptdir}/debian" "${git_dir}"

	# enter source dir
	cd "${git_dir}"

	echo -e "\n==> Updating changelog"
	sleep 2s

 	# update changelog with dch
	if [[ -f "debian/changelog" ]]; then

		dch -p --force-distribution -v "${pkgver}+${pkgsuffix}-${upstream_rev}" -M --package \
		"${pkgname}" -D "${DIST}" -u "${urgency}" "Bump version of virtual package."
		nano "debian/changelog"

	else

		dch -p --create --force-distribution -v "${pkgver}+${pkgsuffix}-${upstream_rev}" \
		-M --package "${pkgname}" -D "${DIST}" -u "${urgency}" "Initial upload"

	fi

	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	USENETWORK=$USENETWORK DIST=$DIST ARCH=$ARCH ${BUILDER} ${BUILDOPTS}

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
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
			--filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}


			# uplaod local repo changelog
			cp "${git_dir}/debian/changelog" "${scriptdir}/debian"

			# If using a fork instead with debiain/ upstream
			#cd "${git_dir}" && git add debian/changelog && git commit -m "update changelog" && git push origin "${branch}"
			#cd "${scriptdir}"

		fi

	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
