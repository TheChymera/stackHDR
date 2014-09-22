#! /bin/bash
#Authors: Edu Perez, Horea Christian

#Set base variables
SELF=`basename $0`
REMOVE_RAW=false
ENFUSE=false
ALIGN=false
KEEP_FILES=false
CLEAN_LOGS=false

#Assign variable values based on user input
while getopts ':d:aekrch' flag; do
    case "${flag}" in
    	d)
	    DIR="$OPTARG"
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
	c)
	    CLEAN_LOGS=true
	    ;;
	h)
	    echo "Syntax:"
	    echo "\$ `basename $0` [-a -e -k -r -c -h] -d <directory-name> || <file-names>"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-c: Clean all log files. Enabling this means you will be unable to debug."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    echo "Syntax:"
	    echo "\$ `basename $0` [-a -e -k -r -c -h] -d <directory-name> || <file-names>"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-c: Clean all log files. Enabling this means you will be unable to debug."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    echo "Syntax:"
	    echo "\$ `basename $0` [-a -e -k -r -c -h] -d <directory-name> || <file-names>"
	    echo "	-d: The directory containing your files (will stack all RAW files therein)."
	    echo "	-a: Align images."
	    echo "	-e: Use enfuse to fuse the images together."
	    echo "	-k: Keep intermediately created files."
	    echo "	-r: Remove original RAW files. DO NOT USE unless your files are backed up."
	    echo "	-c: Clean all log files. Enabling this means you will be unable to debug."
	    echo "	-h: Show this message."
	    exit 1
	    ;;
    esac
done

#Shifts pointer to read mandatory output file specification
shift $(($OPTIND - 1))
FILES=($@)

#Check if either $FILES or $DIR is specified and assign the other variable accordingly
if [ -z $FILES ]; then
    if [ -n $DIR ]; then
	echo "lala"
	FILES=("$DIR"/*.{NEF,nef,NRW,nrw,CR2,cr2,PEF,pef,PTX,ptx,PXN,pxn,SR2,sr2,SRF,srf,SRW,srw})
	FILES=(${FILES[@]//*\**/})
    else
	echo "No files selected! You need to specify either a -d option or a list of files."
    fi
else
    if [[ ${FILES[0]} == */* ]]; then
	DIR=${FILES[0]%/*}
    else
	DIR="."
    fi
fi

#Check whether the option flags are grabbed by $FILES  
if [[ ${FILES[@]} == *[[:space:]]-* ]]; then
    echo "WARNING: Your file list seems to contain an option flag."
    echo "	 If the script fails, please make sure you have"
    echo "	 specified the flags before the files list."
fi

#Check if any files match the criteria specified by the user
COUNT=${#FILES[@]}
if [ $COUNT -eq 0 ]; then
    echo "$SELF: No files found!!!"
    exit 1
fi

#Summary of input
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

#Remove original RAW input if thus specified by the user
if $REMOVE_RAW; then
    echo "$SELF: Removing original RAW files:"
    rm -f ${FILES[*]}
fi

#Remove all logs
if $CLEAN_LOGS; then
    echo "$SELF: Removing all log files:"
    rm -f "$DIR"/enfuse.log "$DIR"/align_image_stack.log
fi
