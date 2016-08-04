#!/bin/bash

# -------------------------------------------------------------------------------
# Author:    	Michael DeGuzis
# Git:	    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-deb-from-PPA.sh
# Script Ver:	0.5.6
# Description:	Attempts to build a deb package from a PPA
#
# See also:	Generate a source list: http://repogen.simplylinux.ch/
#		Command 'rmadison' from devscripts to see arch's
#		Command 'apt-cache madison <PKG>'
#
# Usage:	./build-deb-from-PPA.sh
#		source ./build-deb-from-PPA.sh
#		./build-deb-from-PPA.sh --ignore-deps
#		./build-deb-from-PPA.sh --binary
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

# builder varzs
DIST="brewmaster"
ARCH="amd64"
BUILDOPTS="--debbuildopts -b"
export BUILD_DIR="${BUILD_DIR}"

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

###############################
# Notes regarding some sources
###############################

# Ubuntu packages are not "PPA's" so example deb-src lines are:
# deb-src http://archive.ubuntu.com/ubuntu wily main restricted universe multiverse
# GPG-key(s): 437D05B5, C0B21F32

show_help()
{
	clear
	cat <<-EOF
	####################################################
	Usage:	
	####################################################
	./build-deb-from-PPA.sh
	./build-deb-from-PPA.sh --help
	./build-deb-from-PPA.sh --ignore-deps
	source ./build-deb-from-PPA.sh
	
	The fourth option, preeceded by 'source' will 
	execute the script in the context of the calling 
	shell and preserve vars for the next run.
	
	IF you see the message:
	WARNING: The following packages cannot be authenticated!...
	Look above in the output for apt-get update. You will see a
	line for 'NO_PUBKEY 3B4FE6ACC0B21F32'. Import this key string
	by issuing 'gpg_import.sh <key>' from the extra DIR of this repo.
	
	EOF
	
}

if [[ "$arg1" == "--help" ]]; then

	#show help
	show_help
	exit 1

fi

install_prereqs()
{

	clear
	# set scriptdir
	scriptdir="$pwd"
	
	echo -e "==> Checking for Debian sources..."
	
	# check for repos
	sources_check=$(sudo find /etc/apt -type f -name "jessie*.list")
	sources_check2=$(grep -r jessie /etc/apt/sources.list)
	
	if [[ "$sources_check" == "" && "$sources_check2" == "" ]]; then
                echo -e "\n==INFO==\nSources do *NOT* appear to be added at first glance. Adding now..."
                sleep 2s
                "$scriptdir/add-debian-repos.sh"
        else
                echo -e "\n==INFO==\nJessie sources appear to be added."
                sleep 2s
        fi
        
        echo -e "\n==> Installing build tools...\n"
        sleep 2s
        
        sudo apt-get install -y --force-yes devscripts build-essential checkinstall

}

function_build_locally()
{

	# Ask user for repos / vars
	echo -e "\n==> Please enter or paste the deb-src URL now:"
	echo -e "    [Press ENTER to use last: $repo_src]\n"
	
	# set tmp var for last run, if exists
	repo_src_tmp="$repo_src"
	if [[ "$repo_src" == "" ]]; then
		# var blank this run, get input
		read -ep "deb-src URL: " repo_src
	else
		read -ep "deb-src URL: " repo_src
		# user chose to keep var value from last
		if [[ "$repo_src" == "" ]]; then
			repo_src="$repo_src_tmp"
		else
			# keep user choice
			repo_src="$repo_src"
		fi
	fi
	
	echo -e "\n==> Use a public key string or URL to public key file [s/u]?"
	echo -e "    [Press ENTER to use string (default)\n"
	sleep .2s
	read -erp "Type: " gpg_type
	
	echo -e "\n==> Please enter or paste the GPG key/url for this repo now:"
	echo -e "    [Press ENTER to use last: $gpg_pub_key]\n"
	gpg_pub_key_tmp="$gpg_pub_key"
	if [[ "$gpg_pub_key" == "" ]]; then
		# var blank this run, get input
		read -ep "GPG Public Key: " gpg_pub_key
	else
		read -ep "GPG Public Key: " gpg_pub_key
		# user chose to keep var value from last
		if [[ "$gpg_pub_key" == "" ]]; then
			gpg_pub_key="$gpg_pub_key_tmp"
		else
			# keep user choice
			gpg_pub_key="$gpg_pub_key"
		fi
	fi
	
	echo -e "\n==> Please enter or paste the desired package name now:"
	echo -e "    [Press ENTER to use last: $TARGET]\n"
	TARGET_tmp="$TARGET"
	if [[ "$TARGET" == "" ]]; then
		# var blank this run, get input
		read -ep "Package Name: " TARGET
	else
		read -ep "Package Name: " TARGET
		# user chose to keep var value from last
		if [[ "$TARGET" == "" ]]; then
			TARGET="$TARGET_tmp"
		else
			# keep user choice
			TARGET="$TARGET"
		fi
	fi
	
	# prechecks
	echo -e "\n==> Attempting to add source list"
	sleep 2s
	
	# check for existance of TARGET, backup if it exists
	if [[ -f /etc/apt/sources.list.d/${TARGET}.list ]]; then
		echo -e "\n==> Backing up ${TARGET}.list to ${TARGET}.list.bak"
		sudo mv "/etc/apt/sources.list.d/${TARGET}.list" "/etc/apt/sources.list.d/${TARGET}.list.bak"
	fi
	
	# add source to sources.list.d/
	echo ${repo_src} > "${TARGET}.list.tmp"
	sudo mv "${TARGET}.list.tmp" "/etc/apt/sources.list.d/${TARGET}.list"
	
	echo -e "\n==> Adding GPG key:\n"
	sleep 2s
	
	if [[ "$gpg_type" == "s" ]]; then
	
		# add gpg key by string from keyserver
		sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $gpg_pub_key
		
	elif [[ "$gpg_type" == "u" ]]; then
	
		# add key by specifying URL to public.key equivalent file
		wget -q -O- $gpg_pub_key | sudo apt-key add -
		
	else
	
		# add gpg key by string from keyserver (fallback default)
		sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $gpg_pub_key
		
	fi
	
	echo -e "\n==> Updating system package listings...\n"
	sleep 2s
	sudo apt-key update
	sudo apt-get update
	
	
	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)
	
	# assess if depdencies should be ignored.
	# If no argument used, build normally

	if [[ "$arg1" == "" ]]; then
	
		echo -e "\n==> Attempting to auto-install build dependencies\n"
	
		# attempt to get build deps
		if sudo apt-get build-dep ${TARGET} -y --force-yes; then
		
			echo -e "\n==INFO==\nSource package dependencies successfully installed."
			
		else
			
			echo -e "\n==ERROR==\nSource package dependencies coud not be installed!"
			echo -e "Press CTRL+C to exit now. Exiting in 15 seconds."
			sleep 15s
			exit 1
			
		fi
	
		# Attempt to build TARGET
		echo -e "\n==> Attempting to build ${TARGET}:\n"
		sleep 2s
	
		# build normally using apt-get source
		if apt-get source --build ${TARGET}; then
			
			echo -e "\n==INFO==\nBuild successfull"
			
		else
		
			echo -e "\n==INFO==\nBuild FAILED"
			
		fi
	
	elif [[ "$arg1" == "--ignore_deps" ]]; then
	
		# There are times when specific packages are specific in the depends lines
		# of Ubuntu control files are satisfied by other packages.
		
		# One example is libstdc++6.4.4-dev, which seems to be satisfiable by 
		# libstdc6 in Jessie, where only higher ver. dbg packages are available
		# Ex. https://packages.debian.org/search?suite=jessie&searchon=names&keywords=libstdc%2B%2B6
	
		echo -e "\n==INFO==\nIgnoring depedencies for build\n"
		sleep 2s
		
		# download source 
		apt-get source ${TARGET}
		
		# identify folder
		cd $BUILD_DIR
		build_source_dir=$(ls -d */)
	
		# build using typicaly commands + override option
		cd ${build_source_dir} && dpkg-buildpackage -b -rfakeroot -us -uc -d
	

	elif [[ "$arg1" == "--binary-only" ]]; then


                echo -e "\n==INFO==\nBuilding binary only\n"
                sleep 2s

                # download source
                apt-get source ${TARGET}

                # identify folder
                cd $BUILD_DIR
                build_source_dir=$(ls -d */)

                # build using typicaly commands + override option
                cd ${build_source_dir} && dpkg-buildpackage -b -rfakeroot -us -uc

	fi

	# back out of build temp to script dir if called from git clone
	if [[ "${scriptdir}" != "" ]]; then
		cd "$scriptdir/generic-building"
	else
		cd "${HOME}"
	fi
	
		echo -e "\n==> Would you like to purge this source list addition? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " purge_choice
	
	if [[ "$purge_choice" == "y" ]]; then
	
		# remove list
		sudo rm -f /etc/apt/sources.list.d/${TARGET}.list
		sudo apt-get update
		
	elif [[ "$purge_choice" == "n" ]]; then
	
		echo -e "Purge not requested\n"
	fi

}

function_show_summary()
{

	# inform user of packages
	cat<<- EOF
	###################################################################
	If package was built without errors you will see it below.
	If you do not, please check build dependcy errors listed above.
	You could also try manually building outside of this script with
	the following commands (at your own risk!)
	
	cd $BUILD_DIR"
	cd $build_folder"
	sudo dpkg-buildpackage -b -d -uc"
	###################################################################
	
	EOF

	ls "${HOME}/build-deb-temp"

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# transfer files
			rsync -arv --info=progress2 -e "ssh -p ${REMOTE_PORT}" \
			--filter="merge ${HOME}/.config/SteamOS-Tools/repo-filter.txt" \
			${BUILD_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REPO_FOLDER}

		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

	
}

function_pbuilder_build()
{
	
	# Get DSC
	echo -e "\n==> Using pbuilder. Enter URL to DSC file: "
	sleep 0.2s
	read -erp "URL: " DSC_FILE_URL
	
	echo -e "\n==> Fetching source filse\n"
	dget -xu "${DSC_FILE_URL}"

	echo -e "\n==> Editing DSC file. Be sure to adjust as needed\n"
	sleep 2s
	nano *.dsc

	echo -e "\n==> Buidling package\n"
	sudo -E DIST=$DIST ARCH=$ARCH ${BUILDER} --build *.dsc
	
}

main()
{
	
	clear
	echo -e "\n==> Choose your builder: [pbuilder|local]\n"
	read -erp "Choice: " BUILDER
	
	export BUILD_DIR="${HOME}/build-deb-temp"
	SRCDIR="${PKGNAME}-${PKGVER}"
	
	# remove previous dirs if they exist
	if [[ -d "${BUILD_DIR}" ]]; then
		sudo rm -rf "${BUILD_DIR}"
	fi
	
	# create build dir and enter it
	mkdir -p "${BUILD_DIR}"
	cd "${BUILD_DIR}"
	
	if [[ "${BUILDER}" == "pbuilder" ]]; then
	
		function_pbuilder_build
		
	else
	
		function_build_locally
		
	fi

	# show end summary
	function_show_summary
}

# start main
main
