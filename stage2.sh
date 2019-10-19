#!/usr/bin/env bash

runDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

buildDir="$HOME/test/Source/AUR"
buildList="$runDir/build.txt"

getAuracle() {

  if [[ -z $(command -v auracle 2>/dev/null) ]]
  then
    echo "Could not locate 'auracle'!"
    read -n1 -r -p "Install now? (y/n) " input 
    echo
    case "$input" in  
      y|Y)
        cloneAur "auracle-git"
        buildAur "$srcDir"
        ;; 
      *)
        echo "Wokay!?"
        exit 1
        ;; 
    esac
  fi

}

cloneAur() {

  local pkgName=${1}
  local repoUrl="https://aur.archlinux.org/${pkgName}.git"
  srcDir="$buildDir/$pkgName"

  if [ ! -d "$srcDir" ]
  then
    if git clone "$repoUrl" "$srcDir" 2>/dev/null
    then
      echo "Cloned '$pkgName'"
    fi
  fi

}

buildAur() {

  #pushd "$1" >/dev/null ||exit
  cd "$1" ||exit
  if [ -f "PKGBUILD" ]
  then
    makepkg -si --noconfirm --needed
    return $?
  else
    echo "Could not find 'PKGBUILD' file!"
    return1
  fi
  #popd >/dev/null ||exit
  cd "$(dirname "$0")" ||exit

}

readPkgList() {

  pkgList="$buildList"
  toBuild=()
  while IFS= read -r line
  do
    toBuild+=("${line}")
  done < "${pkgList}"

}

checkPkgExists() {

  pacman -Qs "$1" >/dev/null
  return $?

}

checkAurExists() {

  if [[ -n $(auracle search --literal "^${pkgName}$" 2>/dev/null) ]]
  then
    return 1
  fi

}

buildPkg() {

  while read -r id name _; do
    case $id in
      REPOS)
        echo "Package '$name' will be installed from repos!"
        ;;
      SATISFIED*)
        echo "Package '$name' is already installed!"
        ;;
      AUR|TARGETAUR)
        cloneAur "$name"
        buildAur "$srcDir"
        cd "$(dirname "$0")" || return 1
        ;;
      *)
        echo "Unhandled action '$id' for '$name'"
        ;;
    esac
  done < <(auracle buildorder "$1")

}

usage() {

  echo "Usage: $(basename "$0") -d <PATH>] [-t <MIN>] [-b <MODE>] [-s]"

}

main() {

  if [ ! -d "$buildDir" ]
  then
    mkdir -p "$buildDir"
  fi

  if [ ! -f "$buildList" ]
  then
    echo "Invalid build list '$buildList'"
    exit 1
  fi

  getAuracle
  readPkgList

  for pkg in "${toBuild[@]}"
  do
    if checkPkgExists "$pkg"
    then
      continue
    elif checkAurExists "$pkg"
    then
      buildPkg "$pkg"
    fi
  done

}

# process command line arguments
while getopts :d:t:b:shD ARGS; do
  case "${ARGS}" in
    h|*) usage; exit 1;;
  esac
done
shift $((OPTIND-1))

main

# vim: ft=sh ts=2 sw=0 et:
