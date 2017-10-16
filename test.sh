#!/usr/bin/env bash
#
# @author Tobias Schifftner, @tschifftner

VERSION="1.0.0"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Variables
ERROR_DETECTED=0

### Tests
function test:phplint {
    if [ ! -f tools/phplint.sh ]; then error_exit "tools/phplint.sh not found"; fi
    tools/phplint.sh .modman/ && success "PHPLint OK" || error "PHPLint Failed!"
}

function test:xmllint {
    if [ ! -f tools/xmllint.sh ]; then error_exit "tools/xmllint.sh not found"; fi
    tools/xmllint.sh .modman/ && success "XMLLint OK" || error "XMLLint Failed!"
}

function test:phpcs {
    if [ ! -f tools/phpcs.sh ]; then error_exit "tools/phpcs.sh not found"; fi
    tools/phpcs.sh .modman/ && success "PHPCS OK" || error "PHPCS Failed!"
}

function test:all {
    test:phplint
    test:xmllint
    test:phpcs
}

### Display helper
function error {
    ERROR_DETECTED=1
    echo -e $RED "$1" 1>&2
	echo -e $NC
}

function success {
    echo -e $GREEN "$1" 1>&2
	echo -e $NC
}

function error_exit {
	echo -e "${RED}$1" 1>&2
	exit 1
}

function version {
    echo "${VERSION}"
}

function _format {
    if [ "$#" -eq 1 ]; then
        echo
        printf "${YELLOW}%-35s\n" "$1"
    fi
    if [ "$#" -eq 2 ]; then
        printf " ${GREEN}%-35s ${NC}%-30s\n" "$1" "$2"
    fi
}

function _header {
echo -e "
${GREEN}Test-Helper ${NC}version ${YELLOW}$(version)${NC} by ${GREEN}ambimax® GmbH

${YELLOW}Usage:
${NC}  command [options] [arguments]"
}



# run script
if [ `type -t $1`"" == 'function' ]; then
    echo -e "${NC}"
    ${@}
    exit $ERROR_DETECTED
else

    _header

    _format "Available Commands"

    _format "test"
    _format "test:all" "Run all tests"
    _format "test:phpcs" "Test for phpcs warnings"
    _format "test:phplint" "Test for phplint warnings"
    _format "test:xmllint" "Test for xmllint warnings"

    echo
fi