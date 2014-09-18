#! /bin/bash
#Authors: Edu Perez, Horea Christian

SELF=`basename $0`
REMOVE_RAW=false
ENFUSE=false
ALIGN=false
KEEP_FILES=false

while getopts ':d:f:aekr' flag; do
    case "${flag}" in
    	d)
	    DIR="$OPTARG"
	    ;;
	f)
	    FILES+=("$OPTARG")
	    ;;
	a)
	    ALIGN=true
	    ;;
	e)
	    ENFUSE=true
	    ;;
	k)
	    KEEP_FILES=true
	    ;;
	r)
	    REMOVE_RAW=true
	    ;;
	h)
	    echo "Syntax:"
	    echo "\$ `basename $0` [-d] <directory-name> [-f] <one-filename> [-a -e -k -r]"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-f: File to add to stack, repeat as needed. Files should be in the same directory."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    echo "Syntax:"
	    echo "\$ `basename $0` [-a -e -k -r] [-f] <one-filename> [-d] <directory-name>"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-f: File to add to stack, repeat as needed. Files should be in the same directory."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    echo "Syntax:"
	    echo "\$ `basename $0` [-a -e -k -r] [-f] <one-filename> [-d] <directory-name>"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-f: File to add to stack, repeat as needed. Files should be in the same directory."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
    esac
done

if [ -z "$FILES" ]; then
    if $DIR; then
	FILES=("$DIR"/*.NEF)
    else
	echo "No files selected! You need to specify either a -d or an -f option."
    fi
else
    DIR=${FILES[0]%/*}
fi

COUNT=${#FILES[@]}

if [ $COUNT -eq 0 ]; then
    echo "$SELF: No files found!!!"
    exit 1
fi

echo "$SELF Options:"
echo "	Align      = ${ALIGN}"
echo "	Enfuse     = ${ENFUSE}"
echo "	Files      = ${FILES[*]}"

STRIPPED_FILES=("${FILES[@]%.*}")
FILENAMES=("${STRIPPED_FILES[@]##*/}")

#UFRaw conversion to TIFF:
echo "$SELF: Generating TIFFs"
ufraw-batch --wb=camera --gamma=0.45 --linearity=0.10 --exposure=0.0 --saturation=1.0 --out-type=tiff --out-depth=16 --overwrite --out-path="./$DIR" ${FILES[*]}
TIFF_FILES=("${STRIPPED_FILES[@]/%/.tif}")

#Align images:
if [ "$ALIGN" = true -a $COUNT -gt 1 ]; then
    echo "$SELF: Aligning images"
    align_image_stack -a "$DIR"/AIS_ ${TIFF_FILES[*]} > "$DIR"/align_image_stack.log
    if ! $KEEP_FILES; then
	echo "$SELF: Cleanning primary TIFF files:"
	rm -f ${TIFF_FILES[*]}
    fi
    TIFF_FILES=("$DIR"/AIS_*.tif)
fi

#Fuse images:
if [ "$ENFUSE" = true ]; then
    if [ $COUNT -gt 1 ]; then
	echo "$SELF: Generating enfuse:"
	enfuse -o "$DIR"/"${FILENAMES[0]}"-"${FILENAMES[${#FILENAMES[@]}-1]}"-stack.tif ${TIFF_FILES[*]} > "$DIR"/enfuse.log
    else
	echo "$SELF: By-passing enfuse:"
	ln ${TIFF_FILES[*]} "$DIR"/"${FILENAMES[0]}"-"${FILENAMES[${#FILENAMES[@]}-1]}"-stack.tif
    fi
    if ! $KEEP_FILES; then
	echo "$SELF: Cleanning aligned TIFF files:"
	rm -f ${TIFF_FILES[*]}
    fi
fi
