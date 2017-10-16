#!/usr/bin/env bash
#
# @author Tobias Schifftner, @tschifftner

path=`pwd`
git=`which git`
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_GREEN="\033[0;32m"
COLOR_OCHRE="\033[38;5;95m"
COLOR_BLUE="\033[0;34m"
COLOR_WHITE="\033[0;37m"
COLOR_RESET="\033[0m"

function git_color {
#  git status
  local git_status="$(git status 2> /dev/null)"

  if [[ $git_status =~ "Changes not staged for commit" ]]; then
    echo -e $COLOR_RED $1
    git status
  elif [[ $git_status =~ "Your branch is ahead of" ]]; then
    echo -e $COLOR_YELLOW $1
    git status
  elif [[ $git_status =~ "working directory clean" ]] || [[ $git_status =~ "nothing to commit" ]] || [[ $git_status =~ "branch is up-to-date" ]]; then
    echo -e $COLOR_GREEN $1
  else
    echo -e $COLOR_RED $1
    git status
  fi
}

# Check all roles
for repo in .modman/*
do
    cd $path/$repo/
    if [ -d .git ]; then
        git_color `pwd`
    fi
done

# Reset
echo -e $COLOR_RESET

