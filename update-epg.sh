#!/bin/bash

# BASE Directory for mheg5xmltv
DIR="$HOME/mheg2xmltv"

cd $DIR
# First grab the MHEG5 data
./tools/mheg5grab.sh
RESULT=$?

if [ "$RESULT" -ne 0 ]; then
	echo "ERROR: MHEG5 Grab failed with error code: $RESULT"
	exit -1
fi

# Add options such as -g for guess categories here
./mheg2xmltv.sh -g
RESULT=$?

if [ "$RESULT" -ne 0 ]; then
	echo "ERROR: mheg2xmltv conversion failed with error code: $RESULT"
	exit -1
fi

# Update mythtv database
# For myth version 0.24 or less /usr/bin/mythfilldatabase --xmlfile /tmp/xmltv.xml > /dev/null
# Update for 0.25 and later
# For <= mythtv 0.26 use --update instead of  --only-update-guide
/usr/bin/mythfilldatabase  --only-update-guide --file --sourceid 1 --xmlfile /tmp/xmltv.xml > /dev/null

RESULT=$?

if [ "$RESULT" -ne 0 ]; then
	echo "ERROR: mythfilldatabase failed with error code: $RESULT"
	exit -1
fi
