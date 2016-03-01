# Old code:

	
	# See:	
	# https://forums.unrealtournament.com/showthread.php?14240-How-to-run-UT4-Alpha-build
	# https://forums.unrealtournament.com/showthread.php?12011-Unreal-Tournament-Pre-Alpha-Playable-Build
	
	# Archive source can also be generally noted from:
	# https://aur.archlinux.org/packages/ut4/
	
	current_dir=$(pwd)
	URL="https://s3.amazonaws.com/unrealtournament"
	ut4_zip="UnrealTournament-Client-XAN-2771652-Linux.zip"
	ut4_dir="/home/desktop/ut4-linux/LinuxNoEditor"
	ut4_bin_dir="$ut4_dir/LinuxNoEditor/Engine/Binaries/Linux/"
	ut4_exe="./UE4-Linux-Test UnrealTournament -SaveToUserDir"
	
	ut4_shortcut_tmp="/home/desktop/ue4-alpha.desktop"
	ut4_cli_tmp="/home/desktop/ue4-alpha"
	
	# start apt mode if check
	if [[ "$apt_mode" == "install" ]]; then
	
		if [[ -d "$ut4_dir" ]]; then
			# DIR exists
			echo -e "\nUT4 Game directory found"
		else
			mkdir -p "$ut4_dir"
		fi
		
		cd "$ut4_dir" || exit
	
		#################################################
		# Prerequisites
		#################################################
		
		#################################################
		# Gather files
		#################################################
		
		# sourced from https://aur.archlinux.org/packages/ut4/
		
		echo -e "\n==> Acquiring files...please wait\n"
		
		sleep 2
		
		echo -e "${ut4_zip}"
		wget -O "${ut4_zip}" "${URL}/${ut4_zip}"
		
		#################################################
		# Setup
		#################################################

		unzip -o "${ue4_zip}"
		
		# Mark main binary as executable
		chmod +x "$ut4_bin_dir/UE4-Linux-Test"
		
		#################################################
		# Post install configuration
		#################################################
		
		echo -e "\n==> Creating executable and desktop launcher"
		
		# copy ue4.png into Steam Pictures dir
		sudo cp "$scriptdir/artwork/games/ut4-alpha.png" "/home/steam/Pictures"
		
		cat <<-EOF> ${ue4_cli_tmp}
		#!/bin/bash
		# execute ut4 alpha
		cd $ut4_bin_dir
		$ut4_exe
		EOF
		
		cat <<-EOF> ${ue4_shortcut_tmp}
		[Desktop Entry]
		Name=UT4 alpha
		Comment=Launcher for UT4 Tournament alpha
		Exec=/usr/bin/ut4-alpha
		Icon=/home/steam/Pictures/ut4-alpha.png
		Terminal=false
		Type=Application
		Categories=Game;
		MimeType=x-scheme-handler/steam;
		EOF
		
		# mark exec
		chmod +x ${ut4_cli_tmp}
		
		# move tmp var files into target locations
		sudo mv ${ut4_shortcut_tmp}  "/usr/share/applications"
		sudo mv ${u4_cli_tmp} "/usr/bin"
		
		#################################################
		# Cleanup
		#################################################
		
		# clean up dirs
		
		# return to previous dir
		cd $current_dir || exit
		
		clear
		cat <<-EOF
		-----------------------------------------------------------------------
		Summary
		-----------------------------------------------------------------------

		Installation is finished. You can either run 'ue4-alpha' from
		the command line, or start 'UE4 aplha' from you applications directory.
		The launcher should show up as a non-Steam game as well in SteamOS BPM.
		
		EOF
	
	
	elif [[ "$apt_mode" == "remove" ]]; then
	
		# Add dekstop launcher file here
		# Transfer to /usr/share/applications
		# TODO !!!
		
		#Remove directories, build files, etc if uninstall is specified by user
		echo -e "\n==> Removing related files for UE4-src routine"
		sleep 2s
		
		# remove directories
		sudo rm -rf "/usr/share/applications/ut4-alpha.desktop" "/usr/bin/ut4-alpha" \
		"$ut4_dir"
		
		# end apt mode if check  
	fi
