#!/bin/bash

# Output date format
shopt -s expand_aliases
alias date='date "+[%F %T]"'

# Load config
DIR=$( dirname "${BASH_SOURCE[0]}" )
if [[ ! -e "${DIR}/squash-my-pics.cfg" ]]
then
    echo $( date )' Config file needed.' >&2
    exit 1
fi
source "${DIR}/squash-my-pics.cfg"

# Search for required programs
JPEGTRAN=$( command -v jpegtran )
EXIFTOOL=$( command -v exiftool )
if [[ -z $EXIFTOOL && -n $( command -v perl ) ]]
then
    PERL_VERSION=$( perl -e 'use Config; print int($Config{PERL_REVISION}).".".int($Config{PERL_VERSION});' )
    EXIFTOOL=$( command -v "exiftool-$PERL_VERSION" )
fi
if [[ -z $JPEGTRAN && -z $EXIFTOOL ]]
then
    echo $( date )' Either jpegtran or exiftool need to be installed.' >&2
    exit 1
fi

# Iterate over file arguments
for FILE in "$@"
do

    # Skip if file doesn't exists
    if [[ ! -e "$FILE" ]]
    then
        echo $( date )" File '$FILE' not found." >&2
        continue
    fi

    # Append '.original' to filenames
    ORIGINAL=$( echo "$FILE" | sed 's/\.jpg$/.original.jpg/' )
    mv -f "$FILE" "$ORIGINAL"
    echo $( date )" Processing '$FILE'..."

    # Optimize compression (jpegtran)
    if [[ -n "$JPEGTRAN" ]]
    then
        echo $( date )' > Compress...'
        "$JPEGTRAN" -optimize -progressive -copy all -outfile "$FILE" "$ORIGINAL"
    else
        cp "$ORIGINAL" "$FILE"
    fi

    # Strip meta data (ExifTool)
    if [[ -n "$EXIFTOOL" ]]
    then
        echo $( date )' > Strip meta data...'
        TAGS=()
        [[ ${#PRESERVED_TAGS[@]} -gt 0 ]] && TAGS=(-tagsFromFile "$ORIGINAL" "${PRESERVED_TAGS[@]}")
        "$EXIFTOOL" -quiet -quiet −overwrite_original -all= "${TAGS[@]}" "$FILE"
    fi

    # Keep original only if requested
    $KEEP_ORIGINAL || rm -f "$ORIGINAL"

done
