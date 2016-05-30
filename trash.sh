#!/bin/bash

# 
# trash - Move files to the appropriate .Trash file on Mac OS X. (Intended
#         as an alternative to 'rm' which immediately deletes the file.)
# 
# v0.1   2007-05-21 - Morgan Aldridge <morgant@makkintosshu.com>
#                     Initial version.
# v0.2   2010-10-26 - Morgan Aldridge
#                     Use appropriate .Trashes folder when trashing files
#                     on other volumes. Create trash folder(s) if necessary.
# v0.2.1 2010-10-26 - Morgan Aldridge
#                     No longer using bash built-in regexp support in hopes
#                     of support Mac OS X 10.4 and earlier.
# v0.3   2010-12-07 - Morgan Aldridge
#                     Correctly handle full volume path which is root volume.
#                     Now increments filename if filename already exists in
#                     trash folder (à la Finder).
# v0.4   2011-06-02 - Morgan Aldridge
#                     Option to list trash contents w/disk usage total. Allows
#                     emptying of trash w/confirmation, incl. secure empty.
# 

# global variables
verbose=false
user=$(whoami)
uid=$(id -u "$user")
v=''

# print usage instructions (help)
function usage() {
	printf "Usage: trash [options] file ...\n"
	printf "  -v		verbose output\n"
	printf "  -h		print these usage instructions\n"
	printf "  -l            list trash contents\n"
	printf "  -e            empty trash contents\n"
	printf "  -s		secure empty trash contents\n"
}

# see if any arguments were passed in
if [ $# -gt 0 ]; then
	# if so, step through them all and process them
	while [ $# -gt 0 ]; do
		# see if the user intended us to run in verbose mode
		if [ "$1" = "-v" ]; then
			shift
			verbose=true
		# see if the user requested help
		elif [ "$1" = "-h" ]; then
			shift
			usage
			exit
		# see if the user requested a list of trash contents
		elif [ "$1" = "-l" ]; then
			shift
			num_volumes=0
			total_blocks=0
			# list file contents & calculate size for user's .Trash folder
			if find "/Users/${user}/.Trash" -depth 1 ! -depth 0; then
				num_volumes=$(( $num_volumes + 1 ))
				blocks=$(du -cs "/Users/${user}/.Trash" | tail -n 1 | cut -f 1)
				total_blocks=$(( $total_blocks + $blocks ))
			fi
			# list file contents & calculate size for volume-specific .Trashes folders
			for file in /Volumes/*; do
				if [ -d "$file" ]; then
					folder="${file}/.Trashes/${uid}"
					if [ -d "${folder}" ]; then
						if find "$folder" -depth 1 ! -depth 0; then
							num_volumes=$(( $num_volumes + 1 ))
							blocks=$(du -cs "$folder" | tail -n 1 | cut -f 1)
							total_blocks=$(( $total_blocks + $blocks ))
						fi
					fi
				fi
			done
			# convert blocks to human readable size
			size=0
			if (( $total_blocks >= 2097152 )); then
				size=$(bc <<< "scale=2; $total_blocks / 2097152")
				size="${size}GB"
			elif (( $total_blocks >= 2048 )); then
				size=$(bc <<< "scale=2; $total_blocks / 2048")
				size="${size}MB"
			else
				size=$(bc <<< "scale=2; $total_blocks / 2")
				size="${size}K"
			fi
			printf "%s across %s volume(s).\n" "$size" $num_volumes
			exit
		# see if the user requested to empty the trash contents
		elif [ "$1" = "-e" ]; then
			shift
			if $verbose; then v="-v"; fi
			# confirm that the user wants to empty the trash
			printf "Are you sure you want to empty the trash (this cannot be undone)? "
			read confirm
			if [ "$confirm" = "y" ]; then
				printf "Emptying trash...\n"
				# delete the contents of user's .Trash folder
				find "/Users/${user}/.Trash" -depth 1 ! -depth 0 -print0 | xargs -0 rm $v -r
				# delete the contents of the volume-specific .Trashes folders
				for file in /Volumes/*; do
					if [ -d "$file" ]; then
						folder="${file}/.Trashes/${uid}"
						if [ -d "$folder" ]; then
							find "$folder" -depth 1 ! -depth 0 -print0 | xargs -0 rm $v -r
						fi
					fi
				done
				printf "Done.\n"
			fi
			exit
		# see if the user requested to securely empty the trash contents
		elif [ "$1" = "-s" ]; then
			shift
			if $verbose; then v="-v"; fi
			# confirm that the user wants to securely empty the trash
			printf "Are you sure you want to securely empty the trash (this REALLY cannot be undone)? "
			read confirm
			if [ "$confirm" = "y" ]; then
				printf "Securely emptying trash...\n"
				# securely delete the contents of user's .Trash folder
				find "/Users/${user}/.Trash" -depth 1 ! -depth 0 -print0 | xargs -0 srm $v -r
				# securely delete the contents of the volume-specific .Trashes folders
				for file in /Volumes/*; do
					if [ -d "$file" ]; then
						folder="${file}/.Trashes/${uid}"
						if [ -d "$folder" ]; then
							find "$folder" -depth 1 ! -depth 0 -print0 | xargs -0 srm $v -r
						fi
					fi
				done
				printf "Done.\n"
			fi
			exit
		# handle remaining arguments as if they were files
		else
			#printf "argument: '%s'\n" $1
			#printf "destination: '%s'\n" $TRASH
			if $verbose; then v="-v"; fi
			# determine whether we should be putting this in a volume-specific .Trashes or user's .Trash
			IFS=/ read -r -d '' _ _ vol _ <<< "$1"
			if [[ ("${1:0:9}" == "/Volumes/") && (-n "$vol") && ($(readlink "/Volumes/$vol") != "/") ]]; then
				trash="/Volumes/${vol}/.Trashes/${uid}/"
			else
				trash="/Users/${user}/.Trash/"
			fi
			# create the trash folder if necessary
			if [ ! -d "$trash" ]; then
				mkdir $v "$trash"
			fi
			# move the file to the trash
			if [ ! -e "${trash}$1" ]; then
				mv $v "$1" "$trash"
			else
				# determine if the filename has an extension
				ext=false
				case "$1" in
					*.*) ext=true ;;
				esac
				
				# keep incrementing a number to append to the filename to mimic Finder
				i=1
				if $ext; then
					new="${trash}${1%%.*} ${i}.${1##*.}"
				else
					new="${trash}$1 $i"
				fi
				while [ -e "$new" ]; do
					((i=$i + 1))
					if $ext; then
						new="${trash}${1%%.*} ${i}.${1##*.}"
					else
						new="${trash}$1 $i"
					fi
				done
				
				#move the file to the trash with the new name
				mv $v "$1" "$new"
			fi
			shift
		fi
	done
else
	printf "No files were specified to be moved to the trash.\n\n"
	usage
fi
