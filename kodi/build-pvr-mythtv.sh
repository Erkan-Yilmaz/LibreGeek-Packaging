#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-pvr.mythtv.sh
# Script Ver:	1.0.0
# Description:	Attempts to build a deb package from pvr.mythtv git source
#
# See:		http://kodi.wiki/view/MythTV_PVR/BuildFromSource
# Usage:	build-pvr.mythtv.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)
# reset source command for while loop
src_cmd=""

# addons dir
addons_dir="/home/steam/kodi-addons"

# upstream URL
git_url="git://github.com/janbar/pvr.mythtv.git"

# package vars
release="isengard"
pkgname="kodi-pvr-mythtv"
pkgrel="1"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"
provides="kodi-pvr-mythtv"
pkggroup="video"
requires="kodi"
replaces="kodi-pvr-mythtv"

# set build_dir
build_dir="$HOME/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{
	clear

	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages 
	sudo apt-get -y --force-yes install autoconf automake build-essential pkg-config bc \
	checkinstall
	
	echo -e "\n==> Installing $pkgname build dependencies...\n"
	sleep 2s
	
	# Built from Kodi PPA
	# See: http://forum.kodi.tv/showthread.php?tid=221184
	sudo apt-get -y --force-yes install bison flex libtool intltool zip cmake
}

main()
{
	
	# create and enter build_dir
	if [[ -d "$build_dir" ]]; then
	
		sudo rm -rf "$build_dir"
		mkdir -p "$build_dir"
		cd "$build_dir"
		
	else
	
		mkdir -p "$build_dir"
		cd "$build_dir"
		
	fi
	
	# ensure SteamOS-Tools addons directory is available
	if [[ ! -d "$addons_dir" ]]; then
	
		mkdir -p "$addons_dir"
		
	fi
	
	# install prereqs for build
	install_prereqs
	
	echo -e "\n==> Fetching upstream source\n"
	sleep 2s
	
	# Creaste build files
	mkdir src && cd src
	cd pvr.mythtv ; git checkout isengard
	
	#################################################
	# Build pvr.mythtv
	#################################################
	
	echo -e "\n==> Bulding ${pkgname}\n"
	sleep 3s
	
	mkdir build && cd build
	cmake -DCMAKE_BUILD_TYPE=Release ../pvr.mythtv/
  	
	# make package, fail out if incomplete
	if make; then

  	echo -e "\n==INFO==\n${pkgname} build successful"
  	sleep 2s
		
	else 
	
		echo -e "\n==ERROR==\n${pkgname}build FAILED. Exiting in 15 seconds"
		sleep 15s
		exit 1
		
	fi
	
	#############################################
	# Post package instructions
	#############################################	
	
	# copy library
	cp pvr.mythtv.so ../pvr.mythtv/
	sudo cp -r pvr.mythtv/ /home/steam/.kodi/addons/ 
	
	# copy files to respective locations
	cp pvr.mythtv.so pvr.mythtv/
 
	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	sudo checkinstall --pkgname="$pkgname" --fstrans="no" --backup="no" \
	--pkgversion="$(date +%Y%m%d)+git" --pkgrelease="$pkgrel" \
	--deldoc="yes" --maintainer="$maintainer" --provides="$provides" --replaces="$replaces" \
	--pkggroup="$pkggroup" --requires="$requires" --exclude="/home"

	#################################################
	# Post install configuration
	#################################################
	
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
	
	# back out of build temp to script dir if called from git clone
	if [[ "$scriptdir" != "" ]]; then
		cd "$scriptdir" || exit
	else
		cd "$HOME" || exit
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: ${build_dir}/build: \n"
	ls ${build_dir}/build | grep -E *.deb

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# cut files
		if [[ -d "${build_dir}/build" ]]; then
			scp ${build_dir}/build/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
