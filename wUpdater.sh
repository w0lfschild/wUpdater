#!/bin/bash

#	VERSION: 2

install_app()
{
	./trash.sh "$oldDirectory"
	mv "$replacementApp" "$oldDirectory"
	echo ""
	echo "Process complete"
	sleep 1
	open -a "$oldDirectory"
}

pinger() 
{
	myurl=www.google.com
	results=$(ping -c 1 -t 5 "$myurl" 2>/dev/null || echo "Unable to connect to internet")
	if [[ $results = *"Unable to"* ]]; then
		echo ""
		kill $KILLME
		echo -e "$results"
	else
		ping_success &
		sleep 1
		kill $KILLME
	fi
}

ping_success() 
{
	if [ -e /tmp/version.txt ]; then rm /tmp/version.txt; fi
	curl -\# -L -o /tmp/version.txt "$versionURL" 2> /dev/null
	latestVersion=$(cat /tmp/version.txt)
	rm /tmp/version.txt	
	if [[ "$currentVersion" != "$latestVersion" ]]; then
		if [[ $autoInstall = 1 ]]; then
			update_confimed
		else
			update_prompt $currentVersion $latestVersion
		fi
	else
		echo ""
		echo "No new updates available"
	fi
}

update_prompt() 
{
	result_value=$("${COCOAD}" msgbox --no-newline \
	--float \
	--title "Update available" \
	--text "Your version $1 is not the latest version available!" \
	--informative-text "Would you like to install the latest version: $2" \
	--button1 "Download and Install" \
	--button2 "Don't ask again" \
	--button3 "Cancel")
	
	if [ "$result_value" == "1" ]; then
		echo ""
		echo "Installing..."
		update_confimed
	elif [ "$result_value" == "2" ]; then
		echo ""
		echo "Canceled"
		defaults write ~/Library/Preferences/org.w0lf.wUpdater "$applicationName" 0
	elif [ "$result_value" == "3" ]; then
		echo ""
		echo "Canceled"
	fi
}

update_confimed() 
{
	echo "Downloading update..."
	if [ -e /tmp/"$applicationName".zip ]; then rm /tmp/"$applicationName".zip; fi
	download_wprogress
	
	echo "Extracting update..."
	if [ -e /tmp/"$applicationName".app ]; then rm -r /tmp/"$applicationName".app; fi
	unzip /tmp/"$applicationName".zip -d /tmp > /dev/null
	
	echo "Cleaning up..."
	if [ -e /tmp/"$applicationName".zip ]; then rm /tmp/"$applicationName".zip; fi
	if [ -e /tmp/__MACOSX ]; then rm -r /tmp/__MACOSX; fi
	
	echo "Launching installer..."
	/tmp/"$applicationName".app/Contents/Resources/updates/wUpdater.app/Contents/MacOS/wUpdater "install" "$oldDirectory" "$applicationName"
}

download_wprogress()
{
	curl -\# -L -o /tmp/"$applicationName".zip "$downloadURL" 2> /tmp/updateTracker &
	pids="$pids $!"
	echo $pids
	wait_for_process $pids
	exec 7>&-
	rm -f /tmp/upipe
}

wait_for_process() 
{
	rm -f /tmp/upipe
	mkfifo /tmp/upipe
	"${COCOAD}" progressbar --title "Downloading Update..." --text "Please wait..." < /tmp/upipe &
	exec 7<> /tmp/upipe
	echo -n . >&7

	dlp="Downloading"
	num=0

    local errors=0
    while :; do
        debug "Processes remaining: $*"
        for pid in "$@"; do
            shift
            if kill -0 "$pid" 2>/dev/null; then
                debug "$pid is still alive."
                set -- "$@" "$pid"
                
                if [[ $num = 0 ]]; then
                	dlp="Downloading.  "
                	num=1
                elif	[[ $num = 1 ]]; then
                	dlp="Downloading.. "
                	num=2
                else
                	dlp="Downloading..."
                	num=0
                fi
                output=$(tail -n 1 /tmp/updateTracker) 
                output=${output##* }
                echo "${output} ${dlp} ${output}" >&7
                                
            elif wait "$pid"; then
            	debug "$pid exited with zero exit status."
                echo "100 Download Complete" >&7
                sleep 1
            else
                debug "$pid exited with non-zero exit status."
                ((++errors))
            fi
        done
        (("$#" > 0)) || break
        sleep ${WAITALL_DELAY:-.1}
    done
    ((errors == 0))
    
    exec 7>&-
	rm -f /tmp/upipe
	rm -f /tmp/updateTracker
}

debug() 
{ 
	echo "DEBUG: $*" >/dev/null
}

# Directory stuff
COCOAD=./CocoaDialog.app/Contents/MacOS/CocoaDialog
SCRDIR=$(cd "${0%/*}" && echo $PWD)

for i in "$@"; do
	echo "$i"
done

# Necessary information
# 1 - Check/Install
# 2 - Directory of application to be updated
# 3 - Name of application to be updated
opperation="$1"
oldDirectory="$2"
applicationName="$3"

if [[ $opperation = "install" ]]; then
	if [[ -e "$oldDirectory" ]]; then
		# Find package
		# /Some.app/Content/Resources/updates/w_updater.app/Content/Resources/script
		replacementApp=$(dirname "$SCRDIR")
		for i in {1..5}; do
			replacementApp=$(dirname "$replacementApp")
		done		
		echo "Installing app"
		killall "${applicationName}"
		install_app
	fi
else
	# Necessary information
	# 4 - Current version of application to be updated
	# 5 - URL to check current version
	# 6 - URL to download current version
	# 7 - Install without prompt
	currentVersion="$4"
	versionURL="$5"
	downloadURL="$6"
	autoInstall="$7"
	number=0
	echo -n "Checking for updates"
	while [ 1 ]; do
		echo -n "."
		sleep .4
	done &
	KILLME=$!
	pinger
	wait	
fi 

# END

