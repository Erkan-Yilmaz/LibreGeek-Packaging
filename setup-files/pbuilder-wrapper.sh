#!/bin/bash
# -------------------------------------------------------------------------------
# Author:		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:		pbuilder-wrapper.sh
# Script Ver:		0.5.5
# Description:		Wrapper for working with pbuilder
# Usage:		pbuilder-wrapper.sh [OPERATION] [dist] [arch] [keyring]
#			pbuilder-wrapper.sh --help
# Notes:		For targets, see .pbuilderrc
# -------------------------------------------------------------------------------

# source arguments
export OPERATION="$1"
export DIST="$2"
export ARCH="$3"
export KEYRING="$4"

# Halt if help requested
if [[ "${OPERATION}" == "--help" ]]; then

	show_help

fi

# Set ARCH fallback
if [[ "$ARCH" == "" ]]; then

	ARCH=$(dpkg --print-architecture)

fi

# Set pbuilder-specific vars
export BETA_FLAG="false"
export BASE_DIR="${HOME}/pbuilder"
export BASE_TGZ="${BASE_DIR}/${DIST}-${ARCH}-base.tgz"

show_help()
{

	clear
	cat<<- EOF
	------------------------------------------------
	HELP
	------------------------------------------------
	See 'man pbuilder' or 'sudo pbuilder' for help
	DIST is required.

	pbuilder-wrapper [ACTION][DIST][ARCH][KEYRING]

	Available actions:

	create
	update
	build
	clean
	login
	login-save (--save-after-login)
	execute

	EOF
	exit 1


}

set_creation_vars()
{

	# set var targets

	# set base DIST if requesting a beta
	if [[ "${DIST}" == "brewmaster_beta" || "${DIST}" == "alchemist_beta" ]]; then

		# Set DIST
		DIST=$(sed "s|_beta||g" <<<${DIST}) 
		BETA_FLAG="true"

		# Set extra packages to intall
		# Use wildcard * to replace the entire line
		PKGS="steamos-beta-repo wget ca-certificates"
		sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "$HOME/.pbuilderrc"
		sudo sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "/root/.pbuilderrc"

	else

		# Set extra packages to intall
		# Use wildcard * to replace the entire line
		# None for now
		
		# Correct issue with some 32 bit pkgs under 32 bit chroots
		# See: http://www.xilinx.com/support/answers/61323.html
		if [[ "${ARCH}" == "i386" ]]; then
		
			PKGS="wget ca-certificates libselinux1:i386"
			sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "$HOME/.pbuilderrc"
			sudo sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "/root/.pbuilderrc"	
			
		else
		
			PKGS="wget ca-certificates"
			sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "$HOME/.pbuilderrc"
			sudo sed -i "s|^.*EXTRAPACKAGES.*|EXTRAPACKAGES=\"$PKGS\"|" "/root/.pbuilderrc"
			
		fi

	fi

	cat<<- EOF

	-----------------------------
	Options passed:
	-----------------------------
	DIST="$DIST"
	ARCH="$ARCH"
	KEYRING="$KEYRING"
	BETA_FLAG="false"
	BASETGZ="$BASE_TGZ"
	BASEDIR="$BASE_DIR"
	OPTS="$OPTS"
	EXTRA PACKAGES: "$PKGS"
	-----------------------------

	EOF
	sleep 5s


}

run_pbuilder()
{

	if [[ "$PROCEED" == "true" ]]; then

		# Process actions, exit on fatal error
		if ! sudo ARCH=$ARCH DIST=$DIST pbuilder $OPERATION $OPTS; then

			echo -e "\n${DIST} environment encountered a fatal error! Exiting."
			sleep 3s
			exit 1

		fi

	else

		show_help
	fi

}

main()
{

	# set options
	# For specifying arch, see: http://pbuilder.alioth.debian.org/#amd64i386
	case "$DIST" in

		alchemist|alchemist_beta|brewmaster|brewmaster_beta)
		KEYRING="/usr/share/keyrings/valve-archive-keyring.gpg"
	        ;;

	        wheezy|jessie|stretch|sid)
		KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
	        ;;

		trusty|vivid|willy)
		KEYRING="/usr/share/keyrings/ubuntu-archive-keyring.gpg"
	        ;;

	        *)
	        # use steamos as default
		KEYRING="/usr/share/keyrings/valve-archive-keyring.gpg"
		;;

	esac

	# Process $OPERATION
	case $OPERATION in

		create)
		PROCEED="true"
		OPTS="--basetgz $BASE_TGZ --architecture $ARCH --debootstrapopts --keyring=$KEYRING"
		set_creation_vars
		run_pbuilder
		;;

		login)
		PROCEED="true"
		OPTS="--basetgz $BASE_TGZ"
		run_pbuilder
		;;

		login-save)
		PROCEED="true"
		OPERATION="login"
		OPTS="--basetgz $BASE_TGZ --save-after-login"
		run_pbuilder
		;;

		update|build|clean|login|execute)
		PROCEED="true"
		OPTS="--basetgz $BASE_TGZ --architecture $ARCH --debootstrapopts --keyring=$KEYRING"
		;;

	esac


}

# start main
main
