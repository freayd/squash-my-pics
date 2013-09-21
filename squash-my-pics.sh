#!/bin/bash

# Load config
DIR=$( dirname "${BASH_SOURCE[0]}" )
if [[ ! -e "${DIR}/squash-my-pics.cfg" ]]
then
    echo 'Config file needed.' >&2
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
    echo 'Either jpegtran or exiftool need to be installed.' >&2
    exit 1
fi

# Append '.original' to filenames (unless this file already exists)
find "$FOLDER" -name '*.jpg' ! -name '*.original.jpg' -print0 | while read -d $'\0' FILE
do
    ORIGINAL=$( echo "$FILE" | sed 's/\.jpg$/.original.jpg/' )

    [[ -e "$ORIGINAL" ]] || mv "$FILE" "$ORIGINAL"
done

# Squash .original.jpg files and save result to .jpg
find "$FOLDER" -name '*.original.jpg' -print0 | while read -d $'\0' ORIGINAL
do
    SQUASHED=$( echo "$ORIGINAL" | sed 's/\.original\.jpg$/.jpg/' )

    # Optimize compression (lossless)
    [[ -n "$JPEGTRAN" ]] && "$JPEGTRAN" -optimize -progressive -copy all -outfile "$SQUASHED" "$ORIGINAL"

    # Strip meta data
    TAGS=()
    [[ ${#PRESERVED_TAGS[@]} -gt 0 ]] && TAGS=(-tagsFromFile "$ORIGINAL" "${PRESERVED_TAGS[@]}")
    [[ -n "$EXIFTOOL" ]] && "$EXIFTOOL" -quiet −overwrite_original -all= "${TAGS[@]}" "$SQUASHED"
done

# Remove original if requested
$KEEP_ORIGINAL || (find "$FOLDER" -name '*.original.jpg' -print0 | while read -d $'\0' FILE
do
    rm -f "$FILE"
done)
