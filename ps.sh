#!/usr/bin/env bash

# A simple post-install script to install auracle and a list of packages 
# from AUR. It looks for './build.txt' or use -l to specify a file
# The format is one package per line. Optional second field should be the
# name of package it will replace
# Ex: i3-gaps-next-git i3-gaps
# In this case, i3-gaps will be uninstalled BEFORE building i3-gaps-next-git
# This is circumventing an intentional safeguard in pacman, don't use this

# script path
runDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# AUR cache
buildDir="$HOME/Source/AUR"
# list of packages to build
buildList="$runDir/build.txt"

# stage2
main() {

  # create cache
  if [ ! -d "$buildDir" ]; then
    mkdir -p "$buildDir"
    echo "Created build directory '$buildDir'"
  fi

  # check for build list
  if [ ! -f "$buildList" ]; then
    echo "Invalid build list '$buildList'"
    exit 1
  fi

  # get auracle
  getAuracle

  # read in build list
  readPkgList
  
  # do a bunch of checks then build pkg
  for item in "${toBuild[@]}"; do
    unset replace
    read -r -a fields <<< "$item"

    if [[ "${#fields[@]}" -gt 1 ]]; then
      replace="${fields[1]}"
    fi
    pkg="${fields[0]}"

    if checkPkgExists "$pkg"; then
      continue

    elif checkAurExists "$pkg"; then 
      if checkPkgExists "$replace"; then
        if ! sudo pacman -R --noconfirm "$replace" 2>/dev/null; then
          echo "Failed to remove '$replace' before building '$pkg'!"
        fi
      fi

      buildPkg "$pkg"
    fi
  done

}

# download and install auracle
getAuracle() {

  if [[ -z $(command -v auracle 2>/dev/null) ]]; then
    echo "Could not locate 'auracle'!"
    read -n1 -r -p "Install now? (y/n) " input 
    echo
    case "$input" in
      y|Y)
        cloneAur "auracle-git"
        makePkg "$srcDir"
        ;; 
      *)
        echo "Wokay!?"
        exit 1
        ;; 
    esac
  fi

}

# clone aur repo
cloneAur() {

  local pkgName=${1}
  local repoUrl="https://aur.archlinux.org/${pkgName}.git"
  srcDir="$buildDir/$pkgName"

  if [ ! -d "$srcDir" ]; then
    if git clone "$repoUrl" "$srcDir" 2>/dev/null; then
      echo "Cloned '$pkgName'"
    fi
  fi

}

# build package
makePkg() {

  cd "$1" ||exit

  if [ ! -f "PKGBUILD" ]; then
    echo "Could not find 'PKGBUILD' file in '$1'!"
    return 1
  fi

  makepkg -sric --noconfirm --needed 2>/dev/null
  [ $? == 14 ] && echo "Package '$1' was built, but failed to install"

  cd "$runDir" ||exit
  
}

# read build list into array
readPkgList() {

  pkgList="$buildList"
  toBuild=()
  while IFS= read -r line; do
    toBuild+=("${line[@]}")
  done < "${pkgList}"

}

# check if package is currently installed
checkPkgExists() {

  pacman -Qs "^$1$" >/dev/null
  return $?

}

# check if repo exists on aur
checkAurExists() {

  if [ -n "$(auracle search "^${pkgName}$" 2>/dev/null)" ]; then
    return 1
  fi

}

# parse buildorder, build deps, build target
buildPkg() {

  local target="$1"

  while read -r pkgId pkgName _; do
    case "$pkgId" in
      SATISFIED*)
        echo "Package '$pkgName' is already installed!"
        ;;
      REPOS)
        echo "Package '$pkgName' will be installed from repos!"
        ;;
      AUR)
        echo "Building '$pkgName' as dependency for '$target'"
        buildPkg "$pkgName"
        ;;
      TARGETAUR)
        echo "Building target '$pkgName'"
        cloneAur "$pkgName"
        makePkg "$srcDir"
        ;;
      *)
        echo "Unable to process '$pkgName': '$pkgId'"
        ;;
    esac
  done < <(auracle buildorder "$1")

}

usage() {

  echo "Usage: $(basename "$0") [-l <PATH>]"

}

while getopts l:h ARGS; do
  case "${ARGS}" in
    l) buildList="$runDir/${OPTARG}";;
    h|*) usage; exit 1;;
  esac
done
shift $((OPTIND-1))

main

exit 0

# vim: ft=bash ts=2 sw=0 et:
