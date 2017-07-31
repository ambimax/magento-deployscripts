#!/usr/bin/env bash

function error_exit {
	echo "$1" 1>&2
	exit 1
}

if [ ! -d $1 ] ; then
    error_exit "Invalid dir"
fi

# Run in parallel:
# find -L $1 \( -name '*.php' -o -name '*.phtml' \) -print0 | xargs -0 -n 1 -P 20 php -l

FILES=`find $1 -type f \( -name '*.php' -o -name '*.phtml' \)`

TMP_FILE=/tmp/phplint.tmp
touch $TMP_FILE;

for i in $FILES; do
    md5=($(md5sum $i));
    if grep -Fxq "$md5" $TMP_FILE; then
        continue
    fi

    php -l "$i" || error_exit "Unable to parse file '$i'"
    echo $md5 >> $TMP_FILE
done

echo "No syntax errors detected in $1"