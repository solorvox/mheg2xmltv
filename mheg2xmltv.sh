#!/bin/bash
# MHEG2XMLTV - Freeview DVB-T MHEG to XMLTV EPG converter
# Version: 0.5.0  20171130
# Copyright (C) 2010-2017  Solorvox <solorvox@epic.geek.nz>
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
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Requirements: rb-download, sed, and gawk

# Base directory for rb-download dump
SOURCE_DIR="$HOME/mheg"

# Output filename
OUT_FILE="/tmp/xmltv.xml"

# Service ID (1200 for NZ Freeview)
SERVICE_ID="1200"

# XMLTV Channel ID Replacement
# Format 'channel name,XML channel id,icon path
# Note: Channel name does not get modified, only channel id is changed.
# Modified so I don't have to change Myth settings
DEFAULT_CHANNEL_MAP='TV ONE,tv1.freeviewnz.tv,Channel-TV-One.png
TVONEPLUS1,tv1plus1.freeviewnz.tv,one-plus-one-h.png
TV2,tv2.freeviewnz.tv,Channel-Home-TV-2.png
TV33,tv33.freeviewnz.tv,Channel-Home-33TV.png
TV3,tv3.freeviewnz.tv,Channel-Home-TV-3.png
TV3PLUS1,tv3plus1.freeviewnz.tv,Channel-Home-TV-3Plus1.png
C4,c4.freeviewnz.tv,Channel-Home-C4.png
C42,c42.freeviewnz.tv,Channel-Home-C4.png
TV9,tv9.freeviewnz.tv,channel9.png
TV3Plus1,tv3-plus1.freeviewnz.tv,Channel-Home-TV-3Plus1.png
Māori Television,maori-tv.freeviewnz.tv,Channel-Home-Maori-TV.png
Parliament TV,parliament.freeviewnz.tv,Channel-Home-parliament-TV.png
PRIME,prime.freeviewnz.tv,Channel-Home-Prime.png
ChineseTV8,ctv8.freeviewnz.tv,Channel-Home-Chinese-TV-8.png
tvCentral,tvcentral.freeviewnz.tv,Channel-Home-TV-Central.png
ChoiceTV,topshelf.freeviewnz.tv,choice-home.png
TV Rotorua,rotorua.freeviewnz.tv,tv-rotorua.png
Info-Rotorua,info-rotorua.freeviewnz.tv,Channel-Home-info-Rotorua.png
Channel North Television,channelnorth.freeviewnz.tv,North.png
Trackside,trackside.freeviewnz.tv,Channel-Home-Trackside.png
FOUR,four.freeviewnz.tv,Channel-Home-Four.png
U,u.freeviewnz.tv,Channel-Home-U.png
RadioNZ National,rnz-national.freeviewnz.tv,Channel-Home-Radio-NZ-National.png
RadioNZ Concert,rnz-concert.freeviewnz.tv,Channel-Home-Radio-NZ-Concert.png
George,george-fm.freeviewnz.tv,Channel-Home-GeorgeFM.png
BaseFM,base-fm.freeviewnz.tv,ChannelsHome/basefm.png'

# Base URL for channel icons
CHANNEL_ICON_BASE="http://www.freeviewnz.tv/media/nonumbracoimages/original/ChannelsHome/"

# Metadata file, used for optional information such as series categories
# Default same directory as script.
METADATA="$(pwd)/series-metadata.txt"

# Temp file used during conversion (default mktemp)
TMP_STAGE1=`mktemp`
TMP_STAGE2=`mktemp`
TMP_STAGE3=`mktemp`

# Clean up older data (use with caution)
# Default CLEANUP="find $SOURCE_DIR -ctime +8 -delete"
#CLEANUP="find $SOURCE_DIR -ctime +8 -delete"

## END CONFIG ##

USAGE="$0 [-o output_file] [-i input_directory] [-s service_id] [-h] [-d] [-x] [-v]
	  [-m metadata file] 
	-h	Help/usage
	-v	Be verbose
	-o	Output filename (default /tmp/xmltv.xml)
	-i	Input data directory (default \$HOME/mheg)
	-s	Service ID (default 1200)
	-x	Use crid://name instead of service id (eg 1200) for channel ID
	-d	Use default channel remapping (default none)
	-m	Metadata file, additonal infomation such as catagories.
	-c	Channel map file, overides default values.
	-g	Guess at show data from title/description (Starring = Movie/etc)"

VERBOSE=0
CHANNEL_ID_FIELD="ServiceID"
# Parse cmd line
while getopts ":c:m:o:i:s:hxdvg" opt
do
	case $opt in
 	v )
		VERBOSE=1
		;;	
	c )
		CHANNEL_MAP_FILE="$OPTARG"
		;;
	m )
		METADATA="$OPTARG"
		;;
	o )
		OUT_FILE="$OPTARG"
		;;
	i )
		SOURCE_DIR="$OPTARG"
		;;
	s )
		SERVICE_ID="$OPTARG"
		;;
	h )
		echo "Usage: $USAGE" >&2
		exit 0
		;;
	x )
		CHANNEL_ID_FIELD="crid"
		;;
	g )
		GUESS="YES"
		;;
	d )
		CHANNEL_MAP=$DEFAULT_CHANNEL_MAP
		;;
	? )
		echo "Invalid option: -$OPTARG" >&2
		echo "Usage: $USAGE" >&2
		exit -1
		;;
	esac
done

if [ "$GUESS" == "YES" -a \! -e $METADATA ]; then
	echo "ERROR: Metatdata file is not found.  Either supply one via command line or ensure it is in the current path.";
	exit -1
fi

if [ "$TMP_STAGE1" == "" -o "$TMP_STAGE2" == "" -o "$TMP_STAGE3" == "" ]; then
	echo "ERROR: mktemp failed to allocate temp files ([$TMP_STAGE1], [$TMP_STAGE2], or [$TMP_STAGE3]), aborting."
	exit -1
fi

# Default BASE="$SOURCE_DIR/services/$SERVICE_ID/epg/data"
BASE="$SOURCE_DIR/services/$SERVICE_ID/epgdtt/data"

if [ \! -d "$BASE" ]; then
	echo "ERROR: Source directory [$SOURCE_DIR] does not contain expected data, aborting conversion."
	exit -1
fi

if [ "$CHANNEL_MAP" != "" -o "$CHANNEL_MAP_FILE" != "" ]; then
	if [ "$VERBOSE" -gt 0 ]; then
		echo "Remapping channels using channel map";
	fi
	if [ "$CHANNEL_MAP_FILE" != "" ]; then
		CHANNEL_MAP="$( cat $CHANNEL_MAP_FILE )"	
	fi
	# Build sed channel remap command
	OLDIFS=$IFS
	IFS=$(echo -en "\n\b")
	SEDREMAP="sed "
	for cidmap in ${CHANNEL_MAP}; do
		chan_name=$( echo $cidmap | awk -F, '{printf "%s\n", $1}' )
		new=$( echo $cidmap | awk -F, '{printf "%s\n", $2}' )
		icon=$( echo $cidmap | awk -F, '{printf "%s\n", $3}' )
		SEDREMAP="$SEDREMAP -e "\'"/$chan_name.crid/s|\(crid:[^\x1d]*\)|$new\x1d\1\x1d$icon|"\'""
	done
	IFS=$OLDIFS
fi

# Loop through all the days of data
for day in $( ls "$BASE" );
do
	# Loop for all channels
	for chan in $( ls $BASE/$day/* )
	do
		sid=`basename $chan`
		# Dump everything into master file, remapping in process
		if [ "$CHANNEL_MAP" != "" ]; then
			eval "$SEDREMAP $chan" >> $TMP_STAGE1
		else
			# replace crid with serviceID for easy tagging in myth
			sed "/crid:/s/\x1c/$sid\x1d\x1c/" $chan >> $TMP_STAGE1
		fi
		echo >> $TMP_STAGE1 # extra CR for file break
	done
done

# Reformat MHEG data
# 1c = end of record
# 1d = field seperator
sed -i 's/[\x0a\x0d]/ /g;s/\x1c/\n/g;s/[\x04\x00]//g;s/\x1b[Cc]//g;s/&/&amp;/g' $TMP_STAGE1

# DEBUG
cp $TMP_STAGE1 /tmp/stage1

if [ $? -ne 0 ]; then
	echo "ERROR: Failed reformat data file, aborting."
	exit -1
fi

# Create header and channel list from all channels found in MHEG stream
gawk -f- $TMP_STAGE1 > $OUT_FILE <<EOF
BEGIN {
	FS="\x1d"
	print "<tv date=\"" strftime("%Y%m%d%H%M%S %z", systime()) "\" generator-info-name=\"mheg2xmltv\" "
	print "source-info-name=\"DVB-T MHEG Stream\">"

	channel_ids[""]=0
	channel_count=0
}
{
	if ( \$0 ~ /crid:/)
	{
		displayName=\$3
		i=0;
		cid=\$6
			
		for (chan in channel_ids)
		{
			if (chan == cid )
				break
			else
				i++;
		}

		if (i >= channel_count) 
		{
			channel_ids[cid]=i
			channel_count++

			print "\t<channel id=\"" cid "\">"
			print "\t\t<display-name>" displayName "</display-name>"

			if ( \$7 != "" ) 
				print "\t\t<icon src=\"$CHANNEL_ICON_BASE" \$7 "\" />"

			print "\t</channel>"
		}
	}
}
EOF

if [ "$VERBOSE" -gt 0 ]; then
	
	echo -n "Channels: "
	grep "display-name" $OUT_FILE | sed 's/.*<display-name>\(.*\)<.*$/\1/' | tr '\n' ','
	echo 
fi
# Main event listings, written to temporary stage2 file for further processing
gawk -f- $TMP_STAGE1 > $TMP_STAGE2 <<EOF
BEGIN {

	metadata_categories[""]=0
	metadata_showid_to_title[""]=0

	# Read in the metadata on shows if enabled
	if ( "$METADATA" != "" )
	{
		FS="|"
		while (( getline line < "$METADATA") > 0)
		{
			# Ignore comments, read in metadata
			if (line !~ /^#/)
			{
				split(line, data, "|")
				metadata_categories[data[1]]=data[4]

				# now store the showid into an assoc array mapped to show title
				split(data[3], ids, ",")
				for (i in ids)
					metadata_showid_to_title[ ids[ i ] ]=data[1]
			}
		}
	}

	FS="\x1d"
}
{
	if ( ( \$4 ~ /crid:/ ) || ( \$5 ~ /crid:/ ) )
	{
		chan=\$4
		cid=\$6

		date_conv="date +\"%Y %m %d\" -d \"" \$2 "\""
		date_conv | getline file_date
		close(date_conv)
		date=file_date " 0 0 0"
		next
	}

	# if data is blank, just skip this record
	if ( \$8 == "" ) { next }

	start_time=strftime("%Y%m%d%H%M00 %z", mktime(date) + \$2)
	end_time=strftime("%Y%m%d%H%M00 %z", mktime(date) + \$3)
	sub(/:/, "", \$5)
	show_record=start_time "\t" end_time "\t" cid "\t" \$8 "\t" \$9

	# Episode ID
	if ( \$7 != "" )
	{
		ep_num = \$7
		gsub(/^\//,"", ep_num)
		show_record=show_record "\t" ep_num
	}
	else
	{
		show_record=show_record "\t<blank>"
	}

	# find the show ID number, starting after field 9
	for (i=9; i < NF; i++)
	{
		if ( (\$i ~ /^\//) && (\$i !~ /\.png/) )
			break;
	}
	if (i < NF)
	{
		showid=\$i
		gsub(/^\//,"", showid)
	}

	icon_count=\$10

	# Match icons with known tags
	if ( \$0 ~ /hd\.png/ )
		show_record=show_record "\tyes_hd"
	else
		show_record=show_record "\tno_hd"

	if ( \$0 ~ /dolby\.png/ )
		show_record=show_record "\tyes_dolby"
	else
		show_record=show_record "\tno_dolby"

	if ( \$0 ~ /ear\.png/ )
		show_record=show_record "\tyes_ear"
	else
		show_record=show_record "\tno_ear"

	if ( \$0 ~ /ao\.png/ )
		show_record=show_record "\tao"
	else if ( \$0 ~ /g\.png/ )
		show_record=show_record "\tg"
	else if ( \$0 ~ /pgr\.png/ )
		show_record=show_record "\tpgr"
	else
		show_record=show_record "\tno_rating" 

	# Category fields, try to match on showid first (best match)
	catcount=0
	if ( showid in metadata_showid_to_title )
	{
		show_title=metadata_showid_to_title[ showid ]
		if ( show_title != "")
		{
			split(metadata_categories[ show_title ], categories, ",")
			for (cat in categories)
				show_record=show_record "\t" categories[cat]
		}
	}
	else
 	{
		# fall-back if not matched by showid (second best)
		if ( \$8 in metadata_categories )
		{
			split(metadata_categories[\$8], categories, ",")
			for (cat in categories)
				show_record=show_record "\t" categories[cat]
		}
		else
		{
			# if all else fails, and enabled by command line, guess at it. :)
			if ( "$GUESS" == "YES" )
			{
				title=\$8
				description=\$9
				
				# Generic series
				if (( description ~ /[Ee]pisode/ ) || ( description ~ /[Ss0-9] ?[Ee0-9]/ ))
					show_record=show_record "\tSeries"
				
				# News
				if ( title ~ /[Nn]ews/ )
					show_record=show_record "\tNews"

				# Shopping
				if (( title ~ /[Ss]hopping/ ) || ( title ~ /[Ii]nfomercial/ ))
					show_record=show_record "\tShopping"

				# Spiritual
				if (( title ~ /[Rr]eligion/ ) || ( title ~ /[Rr]eligion/ ) \
					|| ( description ~ /[Rr]eligious [Pp]rogram/) )
					show_record=show_record "\tSpiritual"

				# Travel
				if ( title ~ /[Tt]ravel/ )
					show_record=show_record "\tTravel"
					
				# Movies
				if (( description ~ /Starring/ ) || ( description ~ /[Ss]tars /) \
					|| ( title ~ /Movie:/ ) )
					show_record=show_record "\tMovie"

				# Documentary
				if (( title ~ /[Dd]ocumentary/ ) || ( description ~ /[Dd]ocumentary/ ))	
					show_record=show_record "\t Documentary"

				# Sports
				if (( title ~ /Sport/ ) || ( title ~ /playoff/ ) || ( description ~ /[Ss]ports news/) \
					|| ( title ~ /[Rr]ugby/ ) || ( title ~ /NFL|NBA|NHL[ -]/ ))
					show_record=show_record "\tSports"

				# Comedy
				if ( description ~ /[Cc]omedy/ )
					show_record=show_record "\tComedy"

				# Drama
				if (( description ~ /[Dd]rama/ ) || ( title ~ /[Dd]rama:/ ))
					show_record=show_record "\tDrama"

				# Children
				if ( description ~ /[Cc]hildren [Ss]how/ )
					show_record=show_record "\tChildren"

				# SciFi
				if (( title ~ /[Ss]ci-?[Ff]i/ ) || ( title ~ /[Ss]ci-?[Ff]i/ ))	
					show_record=show_record "\tSciFi"

				# cooking
				if ( ( title ~ /[Cc]ooking/ ) || ( title ~ /[Cc]heif/ ) )
					show_record=show_record "\tFood"

				# Business
				if ( title ~ /[Bb]usiness/ )
					show_record=show_record "\tBusiness"
				
				# Game Show
				if (( title ~ /[Gg]ame [Ss]how/) || ( description ~ /[Gg]ame [Ss]how/) \
					|| ( description ~ /contestant/ ) )
					show_record=show_record "\tGame"

				# Reality
				if ( description ~ /reality series/ )
					show_record=show_record "\tReality\tSeries"

				# Nature/Science
				if (( title ~ /[Ss]cicence/ ) || ( title ~ /[Nn]ature/ ) )
					show_record=show_record "\tScience"


				# Talk Show
				if (( description ~ /daytime talk/ ) || ( description ~ /talk show/ ))
					show_record=show_record "\tTalk"
				
				# Crime 
				if (( description ~ /criminal investigation/ ) \
					|| ( description ~/case.*murder/ ) )
					show_record=show_record "\tCrime"
				
			} 
		}
	}

	print show_record
}
EOF

# Fix for multi-day spanning shows, stage2 -> stage3
gawk -f- $TMP_STAGE2 > $TMP_STAGE3 <<EOF
BEGIN { FS = "\t" } # Use tab file separator
{
	# Save fields we'll need later
	start_time=\$1
	end_time=\$2
	cid=\$3
	title=\$4
	episode_id=\$6
	wholerec=\$0

	# Array for duplicate entries to delete
	delete_list[""]=0

	#  Does the show supposedly finish at midnight?
	if ( end_time ~ /000000 / ) # Note space for ending of time
	{
		found_end=0
		# Loop through Stage2 again. Note field numbers now apply to this new file, not parent file read loop.
		while ((getline < "$TMP_STAGE2") >0)
		{
			# Is there another show starting at the end_time from the first read
			# and on the same channel?
			if (( \$1 == end_time ) && ( \$3 == cid ))
			{
				# Do the title and episode_id match?
				if (( \$4 == title ) && ( \$6 == episode_id ))
				{
					# Read the correct end time from the second listing
					correct_end=\$2
					found_end=1
				}
				else
				{
					# If and only if we find a different show starting at midnight then we
					# can write this show ending at midnight
					print wholerec
				}
				break
			}
		}
		close("$TMP_STAGE2")

		# if we found and fixed an end time
		if ( found_end == 1)
		{
			# Strip off the start/end times and print corrected end time with remainder of record.
			pos=length(start_time) + length(correct_end) + 2;
			trailer=substr(wholerec, pos + 1, length(wholerec)- pos)
			print start_time "\t" correct_end "\t" trailer

			# add entry to the delete list so duplicate will be removed
			delete_list[ delete_count++ ] = title "|" episode_id "|" correct_end
		}
	}

	# Does the show start at midnight?
	else if (\$1 ~ /000000 / ) # Note space for match on end of time string
	{
		# Only print records starting at midnight if the preceding record has a different title 
		found_diff=0

		for (i = 0; i <= delete_count; i++)
		{
			key=title "|" episode_id "|" end_time	
			if ( delete_list[ i ] == key )
				found_diff=1
		}

		# if a match wasn't found then print the record
		if ( found_diff == 0)
			print \$0
	}
	else
	{
		# Record didn't start at midnight, print
		print \$0
	}
}
EOF

# Final main event listings, appended to file because of channel header
# Expected input format (tab seperated)
#      1         2        3      4        5          6         7        8          9           10      11      ...
# start_time stop_time channel title description episode_id hd_flag dolby_flag teletext_flag rating categories ...
gawk -f- $TMP_STAGE3 >> $OUT_FILE <<EOF
BEGIN { FS="\t" }
{
	print "\t<programme channel=\"" \$3 "\" start=\"" \$1 "\" stop=\"" \$2 "\">"
	print "\t\t<title>" \$4 "</title>"
	print "\t\t<desc>" \$5 "</desc>"

	# Episode ID
	if ( \$6 != "<blank>" )
	{
		print "\t\t<episode-num system=\"dd_progid\">" \$6 "</episode-num>"
	}

	for (i=11; i<=NF; i++)
	{
		if ( \$i != "<blank>" )
			print "\t\t<category>" \$i "</category>"
	}

	# Match icons with known tags
	if ( \$7 == "yes_hd" )
	{
		print "\t\t<video>"
		print "\t\t\t<present>yes</present>"
		print "\t\t\t<quality>HDTV</quality>"
		print "\t\t</video>"
	}

	if ( \$8 == "yes_dolby" )
	{
		print "\t\t<audio>"
		print "\t\t\t<stereo>dolby</stereo>"
		print "\t\t</audio>"
	}

	if ( \$9 == "yes_ear" )
	{
		print "\t\t<subtitles type=\"teletext\" />"
	}

	if ( \$10 == "ao" )
	{
		print "\t\t<rating system=\"Freeview\">"
		print "\t\t\t<value>AO</value>"
		print "\t\t</rating>"
	}
	else if ( \$10 == "g" )
	{
		print "\t\t<rating system=\"Freeview\">"
		print "\t\t\t<value>G</value>"
		print "\t\t</rating>"
	}
	else if ( \$10 == "pgr" )
	{
		print "\t\t<rating system=\"Freeview\">"
		print "\t\t\t<value>PGR</value>"
		print "\t\t</rating>"
	}
	print "\t</programme>"
}
END { print "</tv>" }
EOF

# Clean-up temp files and then run cleanup command
rm $TMP_STAGE1 $TMP_STAGE2 $TMP_STAGE3
$CLEANUP
