#!/bin/bash
# MHEG2XMLTV - mheg5grab.sh
# Wrapper script to run redbutton-download 
#
# Copyright (C) 2010-2016 Solorvox <solorvox@epic.geek.nz>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Time to run in seconds, 45-120 seconds is recommended
TIME="60" 

# Path to redbutton download
RB_DOWNLOAD="/usr/local/bin/rb-download"

# Base directory for rb-download dump MHEG-5 data
MHEG5_DIR="$HOME/mheg"

# Service ID
SERVICE_ID="1200"

# Channels configuration file (channels.conf)
CHANNELS="$HOME/.tzap/channels.conf"

# Adapter number, leave blank for default adapter 0
# "-a 1" is adapter 1 (or second tuner)
ADAPTER="-a 1"

# Full command line
COMMAND="$RB_DOWNLOAD $ADAPTER -f $CHANNELS -b $MHEG5_DIR $SERVICE_ID" 

# set channel for tuner before running (leave empty for none IE:  TUNEFIRST="")
# this will set the tuner to the correct frequency before running rbdownload.
TUNEFIRST="/usr/bin/ivtv-tune --freqtable=newzealand --channel=1 --device=/dev/video1"

# Remove old data before running, "TRUE" to remove $MHEG5_DIR/*
REMOVE_OLD="TRUE"
########### END CONFIG #############
# Check for redbutton binary
if [ \! -x $RB_DOWNLOAD ]; then
	echo "ERROR: Redbutton download not found at configuration setting [$RB_DOWNLOAD]." > /dev/stderr
	exit -1
fi

if [ "$TUNEFIRST" != "" ]; then
	$TUNEFIRST > /dev/null
fi

# Make the target directory if missing
if [ \! -d $MHEG5_DIR ]; then
	mkdir -p $MHEG5_DIR;
	if [ $? -ne 0 ]; then
		echo "ERROR: Couldn't find or create data directory [$MHEG5_DIR]." > /dev/stderr
		exit -1
	fi
fi

# Remove old data
if [ "$REMOVE_OLD" == "TRUE" ]; then
	rm -r $MHEG5_DIR/*
fi
	
# Run rb-download
${COMMAND} > /dev/null 2>&1 &
CPID=$!
RESULT="$?"

# If the pid is less than 1, something went wrong, exit
if [ "$CPID" -lt 1 ]; then
	echo "ERROR: Failed to run rb-download, command returned code [$RESULT]" > /dev/stderr
	exit -1
fi
	
# Delay in seconds
sleep $TIME

# Shutdown without terminated message
{ killall $( basename $RB_DOWNLOAD ); wait $CPID; } 2> /dev/null

exit 0
