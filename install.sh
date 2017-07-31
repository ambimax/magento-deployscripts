#!/usr/bin/env bash

MY_PATH=`dirname $(readlink -f "$0")`
RELEASEFOLDER=$(readlink -f "${MY_PATH}/../../..")

function usage {
    echo "Usage:"
    echo " $0 -e <environment> [-r <releaseFolder>] [-s]"
    echo " -e Environment (e.g. production, staging, devbox,...)"
    echo " -s If set the project storage will not be imported"
    echo " -cc If set the cache will be cleared"
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

while getopts 'e:r:s' OPTION ; do
case "${OPTION}" in
        e) ENVIRONMENT="${OPTARG}";;
        r) RELEASEFOLDER=`echo "${OPTARG}" | sed -e "s/\/*$//" `;; # delete last slash
        s) SKIPIMPORTFROMSYSTEMSTORAGE=true;;
        c) CLEARCACHE=true;;
        \?) echo; usage 1;;
    esac
done

if [ ! -f "${RELEASEFOLDER}/htdocs/index.php" ] ; then error_exit "Invalid release folder"; fi
if [ ! -f "${RELEASEFOLDER}/tools/n98-magerun.phar" ] ; then error_exit "Could not find n98-magerun.phar"; fi
if ([ ! -f "${RELEASEFOLDER}/tools/apply.php" ] && [ ! -f "${RELEASEFOLDER}/vendor/aoepeople/zettr/zettr.phar" ]); then error_exit "Could not find zettr.phar nor apply.php"; fi
if [ ! -f "${RELEASEFOLDER}/config/settings.csv" ] ; then error_exit "Could not find settings.csv"; fi


# Checking environment
VALID_ENVIRONMENTS=`head -n 1 "${RELEASEFOLDER}/config/settings.csv" | sed "s/^.*DEFAULT,//" | sed "s/,/ /g" | sed "s/\r//"`

if [ -z "${ENVIRONMENT}" ]; then error_exit "ERROR: Please provide an environment code (e.g. -e staging)"; fi
if [[ " ${VALID_ENVIRONMENTS} " =~ " ${ENVIRONMENT} " ]] ; then
    echo "Environment: ${ENVIRONMENT}"
else
    error_exit "ERROR: Illegal environment code ${ENVIRONMENT}"
fi

echo
echo "Linking to shared directories"
echo "-----------------------------"
SHAREDFOLDER="${RELEASEFOLDER}/../../shared"
if [ ! -d "${SHAREDFOLDER}" ] ; then
    echo "Could not find '../../shared'. Trying '../../../shared' now"
    SHAREDFOLDER="${RELEASEFOLDER}/../../../shared";
fi

if [ ! -d "${SHAREDFOLDER}" ] ; then error_exit "Shared directory ${SHAREDFOLDER} not found"; fi
if [ ! -d "${SHAREDFOLDER}/media" ] ; then error_exit "Shared directory ${SHAREDFOLDER}/media not found"; fi
if [ ! -d "${SHAREDFOLDER}/var" ] ; then error_exit "Shared directory ${SHAREDFOLDER}/var not found"; fi

if [ -d "${RELEASEFOLDER}/htdocs/media" ]; then error_exit "Found existing media folder that shouldn't be there"; fi
if [ -d "${RELEASEFOLDER}/htdocs/var" ]; then error_exit "Found existing var folder that shouldn't be there"; fi

echo "Setting symlink (${RELEASEFOLDER}/htdocs/media) to shared media folder (${SHAREDFOLDER}/media)"
ln -s "${SHAREDFOLDER}/media" "${RELEASEFOLDER}/htdocs/media"  || error_exit "Error while linking to shared media directory"

echo "Setting symlink (${RELEASEFOLDER}/htdocs/var) to shared var folder (${SHAREDFOLDER}/var)"
ln -s "${SHAREDFOLDER}/var" "${RELEASEFOLDER}/htdocs/var"  || error_exit "Error while linking to shared var directory"



echo
echo "Running modman"
echo "--------------"
cd "${RELEASEFOLDER}" || error_exit "Error while switching to release directory"
tools/modman deploy-all --force || error_exit "Error while running modman"



echo
echo "Systemstorage"
echo "-------------"
if [[ -n ${SKIPIMPORTFROMSYSTEMSTORAGE} ]]  && ${SKIPIMPORTFROMSYSTEMSTORAGE} ; then
    echo "Skipping import system storage backup because parameter was set"
else

    if [ -z "${MASTER_SYSTEM}" ] ; then
        if [ -f "${RELEASEFOLDER}/config/mastersystem.txt" ] ; then
            MASTER_SYSTEM=`head -n 1 "${RELEASEFOLDER}/config/mastersystem.txt" | sed "s/,/ /g" | sed "s/\r//"`
        else
            MASTER_SYSTEM="production"
        fi
    fi

    if [[ " ${MASTER_SYSTEM} " =~ " ${ENVIRONMENT} " ]] ; then
        echo "Current environment is the master environment. Skipping import."
    else
        echo "Current environment is not the master environment. Importing system storage..."

        if [ -z "${PROJECT}" ] ; then
            if [ ! -f "${RELEASEFOLDER}/config/project.txt" ] ; then error_exit "Could not find project.txt"; fi
            PROJECT=`cat ${RELEASEFOLDER}/config/project.txt`
            if [ -z "${PROJECT}" ] ; then error_exit "Error reading project name"; fi
        fi

        # Apply db settings
        cd "${RELEASEFOLDER}/htdocs" || error_exit "Error while switching to htdocs directory"
        if [ -f ../vendor/aoepeople/zettr/zettr.phar ]; then
            ../vendor/aoepeople/zettr/zettr.phar apply --groups db ${ENVIRONMENT} ../config/settings.csv || error_exit "Error while applying settings"
        else
            ../tools/apply.php ${ENVIRONMENT} ../config/settings.csv || error_exit "Error while applying settings"
        fi

        if [ -z "${SYSTEM_STORAGE_ROOT_PATH}" ] ; then
            SYSTEM_STORAGE_ROOT_PATH="/home/projectstorage/${PROJECT}/backup/${MASTER_SYSTEM}"
        fi

        # Import project storage
        if [ -d "${SYSTEM_STORAGE_ROOT_PATH}" ]; then
            ../tools/project_reset.sh -e ${ENVIRONMENT} -p "${RELEASEFOLDER}/htdocs/" -s "${SYSTEM_STORAGE_ROOT_PATH}" || error_exit "Error while importing project storage"
        fi
    fi

fi


echo
echo "Applying settings"
echo "-----------------"
cd "${RELEASEFOLDER}/htdocs" || error_exit "Error while switching to htdocs directory"
if [ -f ../vendor/aoepeople/zettr/zettr.phar ]; then
    ../vendor/aoepeople/zettr/zettr.phar apply ${ENVIRONMENT} ../config/settings.csv || error_exit "Error while applying settings"
else
    ../tools/apply.php ${ENVIRONMENT} ../config/settings.csv || error_exit "Error while applying settings"
fi
echo



if [ -f "${RELEASEFOLDER}/htdocs/shell/aoe_classpathcache.php" ] ; then
    echo
    echo "Setting revalidate class path cache flag (Aoe_ClassPathCache)"
    echo "-------------------------------------------------------------"
    cd "${RELEASEFOLDER}/htdocs/shell" || error_exit "Error while switching to htdocs/shell directory"
    php aoe_classpathcache.php -action setRevalidateFlag || error_exit "Error while revalidating Aoe_ClassPathCache"
fi



echo
echo "Triggering Magento setup scripts via n98-magerun"
echo "------------------------------------------------"
cd -P "${RELEASEFOLDER}/htdocs/" || error_exit "Error while switching to htdocs directory"
../tools/n98-magerun.phar sys:setup:run || error_exit "Error while triggering the update scripts using n98-magerun"



# Cache should be handled by customizing the id_prefix!
echo
echo "Cache"
echo "-----"
if [[ -n ${CLEARCACHE} ]]  && ${CLEARCACHE} ; then
    cd -P "${RELEASEFOLDER}/htdocs/" || error_exit "Error while switching to htdocs directory"
    ../tools/n98-magerun.phar cache:flush || error_exit "Error while flushing cache using n98-magerun"
#    ../tools/n98-magerun.phar cache:enable || error_exit "Error while enabling cache using n98-magerun"
else
    echo "skipped"
fi


if [ -f "${RELEASEFOLDER}/htdocs/maintenance.flag" ] ; then
    echo
    echo "Deleting maintenance.flag"
    echo "-------------------------"
    rm "${RELEASEFOLDER}/htdocs/maintenance.flag" || error_exit "Error while deleting the maintenance.flag"
fi

echo
echo "Successfully completed installation."
echo
