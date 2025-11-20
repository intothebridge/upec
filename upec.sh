#!/bin/bash
# this program comes with absolutely NO WARRANTY! For GLP v3 license see github
# CREDITS:
# this script makes use of https://github.com/Andy1978/parse_eit 
# Released to github/upec
#
# this script does NOT take any arguments! All parameters are defined using variables in the heading zone!
#
# =============================== PREREQUISITES ===============================
# in upec's working dir there HAS TO BE the executable parse_eit, see https://github.com/intothebridge/parse_eit
#
# =============================== features =====================================
#
# === Ignore Directories ===
# You can place a file (actually a semaphore) named "upecignore.txt" in a directory. Doing this
# the according directory (and all it's subdirectories!!) will not be scanned by upec. This is
# useful if you have under your recording-tree a directory holding new recordings or a working
# dir for doing conversions.
#
# === Genre Files ====
# upec takes by default the name of the current directory as genre. This may be very convenient
# but there may be cases where you would like to set the genre manually.
# With this version you can place a file named "upecgenre.txt" in a directory. Thus instead
# of the directory name the content string of upecgenre.txt will be used as genre for all
# EIT-files found in this current directory.
#
# =============== Enter or change here the Configuration according to your needs ======
# CAUTION: options are case sensitive!
# BASEPATH="/etc/iwops/upec" # path where upec, logfiles and CSV shoudl reside
BASEPATH="/etc/iwops/upec" # path where upec, logfiles and CSV shoudl reside
VIDEOPATH="/mnt/Recordins"
LOGFILE="$BASEPATH""/upec.log"
DEBUGLOG="$BASEPATH""/upecdebug.log"
REBUILD="y" # if set to 'y' all nfo-files are rebuilt/overwritten
RECURSIVE="y" # if set to 'n' no subdirs will be searched for EIT-files
MINTITLELEN=25 # if the TITLE extracted from short_descriptor is shorter than MINTITLELEN the long description will be added (concatenated)
DRYRUN="n" # set DRYRUN to "y" if NFO files should not be built - then there is just logfiles and the CSV
# a CSV-File where the metadata of ALL movies found is also collected - extremely useful :-)
CSVFile="$BASEPATH""/Filmliste.csv" 
CSVDelimiter="|"
DEBUG="n" # if y debug output will added
CLEARLOG="y" # if y, logfiles will be cleared on start
CLEANUPJSON="n"
VIDEOEXTENSIONS="ts TS mpg webm MPG mp4 MP4 avi AVI mts MTS m4v"



# ============== do not change anything below ! ==============

# Global declarations and initializations
declare -A Nfo # associative array holding the target Nfo field values, e.g. the value for the title and so on
XMLstring="" # output string to be written to the target NFO-file
Genre="" # output string for genre
declare -a NfoFields # array holding the Nfo field labels (enumeration)
declare -A CSVdata # associative array holding the target CSV field values
declare -a CSVFields # array holding the CSV field labels (enumeration)
RETURN=""
if [ $CLEARLOG == "y" ]; then
	echo "" > "$LOGFILE"
	echo "" > "$DEBUGLOG"
fi

# =============== Expert configuration for CSV fields ================
# CSVFields=("title" "outline" "plot" "filename")
CSVFields=("title" "outline" "genre" "filename")
# =====================================================


# Target structure
Title=""
Outline=""
Plot=""
echo "" > "$CSVFile"

# ===================== function LOGTEXT ======================================
# Parameter: Text der ins Logfile geschrieben werden soll
# function for writing text to logfile
function logtext () {
   echo "LOG `date`: " $1 2>&1 | tee -a "$LOGFILE"
   if [ $DEBUG == "y" ]; then
       echo "DEBUG `date`: " $1 2>&1 | tee -a "$DEBUGLOG"
   fi

}   

# ===================== function logdebug  ======================================
# Parameter: Text der ins Logfile geschrieben werden soll
# function for writing text to logfile
function logdebug () {
    if [ $DEBUG == "y" ]; then 
            echo "DEBUG `date`: " $1 2>&1 | tee -a "$DEBUGLOG"
    fi
} 

# ===================== parse video filename =====================================
# Parameter: Videofilename
# Output: via global variable "RETURN"
function parsevideoname () {
Input="$1"
# Separator=" - "
Separator="-"

logdebug "Parse Input: $Input"

# check for input starting with date-time-string
if [[ "$Input" =~ ^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])[[:space:]][0-9]{4}* ]]; then
    logdebug "Valid date"
# extract year (first 4 digits)
# echo "US/Central - 10:26 PM (CST)" | sed -n "s/^.*-\s*\(\S*\).*$/\1/p"
# 
# -n      suppress printing
# s       substitute
# ^.*     anything at the beginning
# -       up until the dash
# \s*     any space characters (any whitespace character)
# \(      start capture group
# \S*     any non-space characters
# \)      end capture group
# .*$     anything at the end
# \1      substitute 1st capture group for everything on line
# p       print it

    Year=${Input:0:4}
    logdebug "filebased Year $Year"
    # search for separator
    if [[ $Input == *"$Separator"* ]]; then
        logdebug "Separator: 8 $Separator 8 found"
        Title=$(echo "$Input" | sed -n 's/^.*'"$Separator"'/ /p')
    fi
    RETURN="$Title"
    logdebug "filebased Title $Title, returning $RETURN"

else
    RETURN="$Input"
    logdebug "Invalid date in video file name, returning $RETURN"
fi

}

# search for separator
if [[ $Input == *"$Separator"* ]]; then
    logdebug "Separator found"
#    Output=$(echo "$Input" | sed -n "s/^.*"$Separator"*"$Separator"/\1/p")
    Output=$(echo "$Input" | sed -n 's/^.*'"$Separator"'/ /p')
fi

logdebug "Output: $Output"
# return: pasted into global RETURN value
RETURN="$Output"

#EIF

# ===================== function recursive_scan ======================================
# Parameter: none, recursive_scan assumes that intended working dir is $PWD
# Caution: 

function recursive_scan () {
#       local TARGET=$1
        local filetrunc
	
#        cd "$TARGET"
        logtext "===== Current working dir `pwd`"

# set genre by current dir (full path stripped)
	Genre=${PWD##*/}
 	logtext "==== Current dir: $PWD ==== Genre by directory: $Genre"
# check for upecgenre. If a upecgenre.txt file is found, use it's content for genre
 	if [ -e "upecgenre.txt" ]; then
 	    Genre=$(cat "upecgenre.txt")
 	    logtext "==== Genre for this directory overwritten with $Genre from upecgenre"
 	fi

# 	loop over all files/dirs in current dir
	for d in *; do
		if [ -d "$d"  ] && [  $RECURSIVE = "y" ]; then
	# object is directory (and not SAVE)
			logtext "==== jumping to subdir $d ===="
 			cd "$d"
 	# set genre by current dir (full path stripped)
 			Genre=${PWD##*/}
 			logtext "==== Current dir: $PWD ==== Genre by directory: $Genre"
 	# check for upecgenre. If a upecgenre.txt file is found, use it's content for genre
 			if [ -e "upecgenre.txt" ]; then
 			    Genre=$(cat "upecgenre.txt")
 			    logtext "==== Genre for this directory overwritten with $Genre from upecgenre"
 			fi
	# recursively call 
 	# check for upecignore. Scan current directory only if "upecignore.txt" is NOT found
 			if [ ! -e "upecignore.txt" ]; then
			    recursive_scan 
 			else
 			    logtext "==== ignoring Subdir $d: `cat upecignore.txt`"
 			fi
 			cd ..
		else
	# =====================================================================
	# object is no directory: process as file
 	# get basename
 			filetrunc=$(echo "${d%%.*}")
 			extension="${d##*.}"
 			logtext " "
 			logtext "====================================================="
 			logtext "Found file: Basename $filetrunc Extension: $extension"
#                        filetrunc=$(echo $d | sed 's/.eit//g')
 			logdebug "Filetrunc: $filetrunc"
            eitfile="$filetrunc.eit"
 			nfofile="$filetrunc.nfo"
 			jsonfile="$filetrunc.json"

 			logtext "Current Genre: $Genre"
#           check file for being an eit-file
            if [ "$extension" == "eit" ]; then
                            logtext "==== found EIT-file:  $eitfile"
                            CurrentDir="$PWD"
# 			    Genre=$(basename "$CurrentDir")
                            Filename="$CurrentDir/""$eitfile"
 	# check for rebuild-option
 			    if [ -e "$nfofile" ] && [ $REBUILD = "y" ]; then
 				logtext "==== found NFO-file $nfofile: rebuilding"
                                parse_eit "$eitfile"
                            fi
 			    if [ ! -e "$nfofile" ]; then
 				logtext "==== NOT found NFO-File $nfofile: creating"
 				parse_eit "$eitfile"
 			    fi
 	# object is no eit-file: look for file being a video file AND eit-file not existing!
 			else
 			    logtext "==== File is no EIT-file - Is file a video file? ===="
 			    fileext=$(echo "${d##*.}")
 			    logdebug "==== Extension: $fileext"

 			    if [[ "$VIDEOEXTENSIONS" =~ "$fileext" ]] && [ ! -f "$eitfile" ]; then
 				logtext "File is Video file and NO eit-file existing"
#===================================== Heir gehts weiter:
# Video file gefunden aber kein EIT
# Analysiere den Videonamen und entferne Datum und Provider ("nackter Filename")
# Aus Datum extrahiere das Jahr 
# schreibe Metadaten:
                                logdebug "Parsing $filetrunc filebased"
                                parsevideoname "$filetrunc"
                                Title="$RETURN"
                                logdebug "Filename (Title) after normalization: $Title"
                                nfofile="$filetrunc.nfo"
                                
                                if [ -e "$nfofile" ] && [ $REBUILD = "y" ]; then
                                    logtext "==== found NFO-file $nfofile: rebuilding"
                                    parse_filebased "$filetrunc"
                                fi
                                if [ ! -e "$nfofile" ]; then
                                    logtext "==== NOT found NFO-File $nfofile: creating"
                                    parse_filebased "$filetrunc"
                                fi
 		       	    else
                        logtext "WARNING: File not EIT and no video file --> Skip $d"
 			    fi
 			    if [ $CLEANUPJSON == "y" ]; then
 			        logtext "Cleaning up Jsonfile $jsonfile"
                    rm "$jsonfile"
                fi

 			fi
		fi
	done
        logtext "=== recursive scan finished! ==="
	return 0	
}
# END of recursive_scan


# ====== 
function build_XMLstring {
XMLstring=""
for tag in ${NfoFields[@]}; do
        XMLstring=$XMLstring"<"$tag">"${Nfo[$tag]}"</"$tag">" 
done
# add movie-tag
XMLstring="<movie>"$XMLstring"</movie>"
logdebug "XMLstring: $XMLstring"
}

# ====== 
function write_CSVdata {
CSVstring=""
for tag in ${CSVFields[@]}; do
        CSVstring=$CSVstring${CSVdata[$tag]}$CSVDelimiter
done

# append to CSVfile
logtext "Appending CSVstring: $CSVstring to §CSVFile"
echo "$CSVstring" >> "$CSVFile"
}



# ========================== parse_filebased ==================
# parameter: filename (without extension, normalized)
function parse_filebased ()
{
logtext "============= Processing filebased: $1 =================="
file="$1"
# important: initialize/reset global variables!
XMLstring=""

# nfo is the file extention KODI is expecting
filexml="$file.nfo"
fileraw="$file.raw"
logtext "Target XML: $filexml"

logdebug "Processing: $file"

# ============= Posting Raw ========== (just for debug)
# echo $info2 > "$fileraw"

# Posting XML
logdebug "==== XML-Fields ===="
logdebug "Title: $Title"
Outline="no outline"
logdebug "Outline: $Outline"
Plot="no Plot"
logdebug "Plot: $Plot"
logdebug "Genre: $Genre"
logdebug "===== EOF XML ======="

# Map Fields to XML-Output# ===== producing XML ===============

logdebug "Finished processing $file - setting Nfo-Fields"
NfoFields=("title" "outline" "genre" "plot")
Nfo[title]="$Title"
Nfo[outline]="$Outline"
Nfo[plot]="$Plot"
Nfo[genre]="$Genre"

# Map fields to CSV output
# CSVFields=("title" "outline" "plot" "filename") - CHANGE: moved CSV-field-enumeration to configuration part
CSVdata[filename]="$file"
CSVdata[title]="$Title"
CSVdata[outline]="$Outline"
CSVdata[plot]="$Plot"
CSVdata[genre]="$Genre"

# ===== producing XML ===============# ===== producing XML ===============

logdebug "Building $filexml"

build_XMLstring

write_CSVdata

logdebug "XMLstring: $XMLstring"
if [ $DRYRUN == "y" ]; then
    logdebug "NOT written $filexml (DRYRUN!)"
else
    echo $XMLstring > "$filexml"
    logdebug "written: $filexml"
fi

logdebug "Finished processing $file"

# logdebug "Building $filexml"

logdebug "=============== Finished filebased processing $file"

} # === END parse_filebased ====



# ========================== parse_eit ==================
# parameter: filename of EIT file
function parse_eit ()
{

file="$1"
XMLstring=""

# build normalized filenames
file2=$(echo "$file" | sed 's/.eit//g')
# nfo is the file extention KODI is expecting
filexml="$file2.nfo"
fileraw="$file2.raw"
filejson="$file2.json"

logtext "Outputfiles: $filexml, $filejson, $fileraw"

# ======================= generate temporary json from EIT ===================================
logtext "Starting tool parse_eit for $file"

logtext "Use Executable $Executable"
result=$("$BASEPATH/parse_eit" "$file" > "$filejson")
logtext "Generated $filejson"

# Cleanup x-Tag-Block:
sed -i "s;<x>NOWNEXT</x>;;" "$filejson"
sed -i "s;<x>SCHEDULE</x>;;" "$filejson"
sed -i "s;<x>;;" "$filejson"
sed -i "s;</x>;;" "$filejson"

# Target variable for long text
Plot=$(cat "$filejson" | jq '.extended_event_descriptor.text')
Title=$(cat "$filejson" | jq '.short_event_descriptor_1.event_name')
Outline=$(cat "$filejson" | jq '.short_event_descriptor_1.text')

# if title shorter MINTITLELEN then add outline
if [ ${#Title} -lt $MINTITLELEN ]; then
    logtext "Title shorter than $MINTITLELEN, concatening outline"
    Title="$Title - $Outline"
fi

# Cleanup Quotes:
Title=$(echo "$Title" | tr -d '"')
Outline=$(echo "$Outline" | tr -d '"')
Plot=$(echo "$Plot" | tr -d '"')


# Genre="Genre"

logdebug "Processing: $file"
logdebug "Json file: $filejson"

# ============= Posting Raw ========== (just for debug)
# echo $info2 > "$fileraw"

# Posting XML
logdebug "==== XML-Fields ===="
logdebug "Title: $Title"
logdebug "Outline: $Outline"
logdebug "Plot: $Plot"
logdebug "Genre: $Genre"
logdebug "===== EOF XML ======="

# Map Fields to XML-Output
NfoFields=("title" "outline" "genre" "plot")
Nfo[title]="$Title"
Nfo[outline]="$Outline"
Nfo[plot]="$Plot"
Nfo[genre]="$Genre"

# Map fields to CSV output

CSVdata[title]="$Title"
CSVdata[outline]="$Outline"
CSVdata[plot]="$Plot"
CSVdata[genre]="$Genre"
CSVdata[filename]="$file"


# ===== producing XML ===============

logdebug "Building $filexml"

build_XMLstring

write_CSVdata

logdebug "XMLstring: $XMLstring"
if [ $DRYRUN == "y" ]; then
    logdebug "NOT written $filexml (DRYRUN!)"
else
    echo "$XMLstring" > "$filexml"
#    echo $XMLstring | iconv -f ISO-8859-1 -t ASCII//TRANSLIT > "$filexml"
    logdebug "written: $filexml"
fi

logdebug "Finished processing $file"

} # === END parse_eit ====



function to_printable {
# return value is written to global RETURN

# do charset-converion
RETURN=$(echo $1 | iconv -f ISO-8859-1 -t ASCII//TRANSLIT)

# remove remaining not printable characters
RETURN=$(echo $RETURN | sed 's/[^[:print:]]/ /g;')
logdebug $RETURN
}


# =============================
# Main
# =============================

logtext "================ UPEC - a ultra simple EIT Converter ======================"

cd "$VIDEOPATH"
recursive_scan

logtext "============== UPEC finished - thank you for using me! =================="


exit 0


# EOF
