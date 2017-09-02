#!/usr/bin/env bash

function usage {
    echo "Usage:"
    echo " $0 -f <packageFilename> -b <buildNumber> [-g <gitRevision>] [-r <projectRootDir>]"
    echo " -f <packageFilename>    file name of the archive that will be created"
    echo " -b <buildNumber>        build number"
    echo " -g <gitRevision>        git revision"
    echo " -r <projectRootDir>     Path to the project dir. Defaults to current working directory."
    echo ""
    exit $1
}

function error_exit {
	echo "$1" 1>&2
	exit 1
}

function usage_exit {
    echo "$1" 1>&2
    usage 1
}

PROJECTROOTDIR=$PWD
HISTORY=''
CURRENT_DATE=`date '+%Y-%m-%d %H:%M:%S'`

########## get argument-values
while getopts 'f:b:g:d:r:' OPTION ; do
case "${OPTION}" in
        f) FILENAME="${OPTARG}";;
        b) BUILD_NUMBER="${OPTARG}";;
        g) GIT_REVISION="${OPTARG}";;
        r) PROJECTROOTDIR="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done

if [ -z ${FILENAME} ] ; then usage_exit "ERROR: No file name given (-f)"; fi
if [ -z ${BUILD_NUMBER} ] ; then usage_exit "ERROR: No build number given (-b)"; fi

cd ${PROJECTROOTDIR} || error_exit "Changing directory failed"

if [ ! -f 'composer.json' ] ; then error_exit "Could not find composer.json"; fi
if [ ! -f 'tools/composer.phar' ] ; then error_exit "Could not find composer.phar"; fi

if type "hhvm" &> /dev/null; then
    PHP_COMMAND=hhvm
    echo "Using HHVM for composer..."
else
    PHP_COMMAND=php
fi

TAR_COMMAND='tar -czf'

dpkg -l pigz > /dev/null 2>&1
if [ $? == '0' ]; then
    TAR_COMMAND='tar -I pigz -cf'
    echo "Using pigz for compression..."
fi

if [[ -f CHANGELOG.md ]]; then
    HISTORY=`cat CHANGELOG.md`
    :> CHANGELOG.md
fi


# Run composer
$PHP_COMMAND tools/composer.phar install --verbose --no-ansi --no-interaction --prefer-source 2>&1 | tee composer.log || error_exit "Composer failed"

PACKAGE_REGEX="^Package operations"
SCAN=0
while read line
do
    if [[ $line = 'Writing lock file' ]]; then break; fi;

    if [[ "$line" =~ $PACKAGE_REGEX ]]; then
        SCAN=1;
        echo
        if [ -z ${BUILD_NUMBER} ]; then
            echo "$CURRENT_DATE:"
        else
            echo "Build ${BUILD_NUMBER} from $CURRENT_DATE:"
        fi;
    fi;

    if [[ $SCAN -eq 0 ]]; then
        continue;
    else
        echo $line;
    fi;
done < composer.log > CHANGELOG.md

# Add history again
echo "$HISTORY" >> CHANGELOG.md

# Some basic checks
if [ ! -f 'htdocs/index.php' ] ; then error_exit "Could not find htdocs/index.php"; fi
if [ ! -f 'tools/modman' ] ; then error_exit "Could not find modman script"; fi
if [ ! -d '.modman' ] ; then error_exit "Could not find .modman directory"; fi
if [ ! -f '.modman/.basedir' ] ; then error_exit "Could not find .modman/.basedir"; fi

if [ -d patches ] && [ -f vendor/ambimax/magento-deployscripts/apply_patches.sh ] ; then
    cd "${PROJECTROOTDIR}/htdocs" || error_exit "Changing directory failed"
    bash ../vendor/ambimax/magento-deployscripts/apply_patches.sh || error_exit "Error while applying patches"
    cd ${PROJECTROOTDIR} || error_exit "Changing directory failed"
fi

# Run modman
# This should be run during installation
# tools/modman deploy-all --force

# Write file: build.txt
echo "${BUILD_NUMBER}" > build.txt

# Write file: version.txt
echo "Build: ${BUILD_NUMBER}" > htdocs/version.txt
echo "Build time: `date +%c`" >> htdocs/version.txt
if [ ! -z ${GIT_REVISION} ] ; then echo "Revision: ${GIT_REVISION}" >> htdocs/version.txt ; fi

# Add maintenance.flag
touch htdocs/maintenance.flag

# Create package
if [ ! -d "artifacts/" ] ; then mkdir artifacts/ ; fi

tmpfile=$(tempfile -p build_tar_base_files_)

# Backwards compatibility in case tar_excludes.txt doesn't exist
if [ ! -f "config/tar_excludes.txt" ] ; then
    touch config/tar_excludes.txt
fi

BASEPACKAGE="artifacts/${FILENAME}"
echo "Creating base package '${BASEPACKAGE}'"
${TAR_COMMAND} "${BASEPACKAGE}" --verbose \
    --exclude=./htdocs/var \
    --exclude=./htdocs/media \
    --exclude=./artifacts \
    --exclude=./tmp \
    --exclude-from="config/tar_excludes.txt" . > $tmpfile || error_exit "Creating archive failed"

EXTRAPACKAGE=${BASEPACKAGE/.tar.gz/.extra.tar.gz}
echo "Creating extra package '${EXTRAPACKAGE}' with the remaining files"
${TAR_COMMAND} "${EXTRAPACKAGE}" \
    --exclude=./htdocs/var \
    --exclude=./htdocs/media \
    --exclude=./artifacts \
    --exclude=./tmp \
    --exclude-from="$tmpfile" .  || error_exit "Creating extra archive failed"

rm "$tmpfile"

cd artifacts
md5sum * > MD5SUMS