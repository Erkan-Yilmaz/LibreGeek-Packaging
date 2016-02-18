#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-deb-from-PPA.sh
# Script Ver:	0.1.7
# Description:	Attempts to build a deb package from a git src
#
# Usage:	sudo ./build-deb-from-src.sh
#		source ./build-deb-from-src.sh
#
# See:		https://wiki.debian.org/CheckInstall
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

# repo destination vars (use only local hosts!)
USER="mikeyd"
HOST="archboxmtd"

if [[ "$arg1" == "--testing" ]]; then

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming_testing"
	
else

	REPO_FOLDER="/home/mikeyd/packaging/SteamOS-Tools/incoming"
	
fi

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./build-deb-from-src.sh
	./build-deb-from-src.sh --help
	source ./build-deb-from-src.sh
	
	The third option, preeceded by 'source' will 
	execute the script in the context of the calling 
	shell and preserve vars for the next run.
	
	EOF
}

if [[ "$arg" == "--help" ]]; then
	#show help
	show_help
	exit
fi

install_prereqs()
{
	clear
	echo -e "==> Assessing prerequisites for building...\n"
	sleep 1s
	# install needed packages
	sudo apt-get install -y --force-yes git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring cmake g++ g++-multilib \
	libqt4-dev libqt4-dev libxi-dev libxtst-dev libX11-dev bc libsdl2-dev \
	gcc gcc-multilib

}

main()
{
	export build_dir="/home/desktop/build-deb-temp"
	git_dir="$build_dir/git-temp"
	
	clear
	# create build dir and git dir, enter it
	# mkdir -p "$git_dir"
	# cd "$git_dir"
	
	# Ask user for repos / vars
	echo -e "==> Please enter or paste the git URL now:"
	echo -e "[ENTER to use last: $git_url]\n"
	
	# set tmp var for last run, if exists
	git_url_tmp="$git_url"
	if [[ "$git_url" == " ]]; then
		# var blank this run, get input
		read -ep "Git source URL: " git_url
	else
		read -ep "Git source URL: " git_url
		# user chose to keep var value from last
		if [[ "$git_url" == " ]]; then
			git_url="$git_url_tmp"
		else
			# keep user choice
			git_url="$git_url"
		fi
	fi
	
	# Clone git upstream source
	git clone "$git_url" "$git_dir"	
	
	#################################################
	# Build PKG
	#################################################
	
	# Output readme via less to review build notes first
	echo -e "\n==> Opening any available README.md to review build notes..."
	sleep 2s
	
	readme_file=$(find . -maxdepth 1 -type f \( -name "readme" -o -name "README" -o -name "README.md" -o -name "readme.md" \))
	
	less "$readme_file"
	
	# Ask user to enter build commands until "done" is received
	echo -e "\nPlease enter your build commands, pressing [ENTER] after each one."
	echo -e "When finished, please enter the word 'done' without quotes\n\n"
	sleep 1s
	
	while [[ "$src_cmd" != "done" ]];
	do
	
		# ignore executing src_cmd if "done"
		if [[ "$src_cmd" == "done" ]]; then
			# do nothing
			echo " > /dev/null
		else
			# Execute src cmd
			$src_cmd
		fi
		
		# capture command
		read -ep "Build CMD >> " src_cmd
		
	done
  
	############################
	# proceed to DEB BUILD
	############################
	
	echo -e "\n==> Building Debian package from source"
	echo -e "When finished, please enter the word 'done' without quotes"
	sleep 2s
	
	# build deb package
	sudo checkinstall --fstrans="no" --backup="no" \
	--pkgversion="$(date +%Y%m%d)+git" --deldoc="yes" --exclude="/home"

	# Alternate method
	# dpkg-buildpackage -us -uc -nc

	#################################################
	# Post install configuration
	#################################################
	
	# TODO
	
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
	if [[ "${scriptdir}" != "" ]]; then
		cd "${scriptdir}"
	else
		cd "${HOME}"
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: $git_dir: \n"
	ls "$git_dir"

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# transfer files
		if -d $git_dir/ build; then
			rsync -arv --filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" ${git_dir}/ ${USER}@${HOST}:${REPO_FOLDER}

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main

	if [[ ${BUILDER} ${BUILDOPTS} != "pdebuild" ]]; then

		# handle prereqs on host machine
		install_prereqs

	fi

main

