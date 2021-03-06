#!/usr/bin/env bash

# fini - a simple menu-driven Arch Linux install script

# EDIT DEFAULTS
DEFKEYMAP="us"              # KEYBOARD LAYOUT
DEFLOCALE="en_US"           # LOCALE
DEFVCFONT="default8x16"     # CONSOLE FONT
DEFTIMZON="America/Chicago" # TIMEZONE REGION/CITY
DEFEDITOR="vim"             # TEXT EDITOR

# DO NOT EDIT
RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PKG_LIST="$RUN_DIR/packages.txt"
FETCH_URL="https://github.com/jeffmhubbard/fini/archive/master.tar.gz"
CACHE_TGZ="/tmp/fini.tgz"

##############################################################################

main() {

  if [ ! "${chroot}" = "1" ]; then

    if checkNetwork; then
      syncTime
      pacmanConf "/etc/pacman.conf"
      syncPacman
      checkMount
      checkVBox
      installMenu
    else
      exit 1
    fi
  else

    case ${command} in
      "settimeutc") chrootSetTimeUTC;;
      "settimelocal") chrootSetTimeLocal;;
      "enabletimesyncd") chrootEnableTimesync;;
      "setlocale") chrootSetLocale;;
      "enabledhcpcd") chrootEnableDHCP;;
      "enablexdm") chrootEnableXDM;;
      "grubinstall") chrootInstallGrub;;
      "grubinstallbios") chrootInstallGrubBIOS "${args}";;
      "grubinstallefi") chrootInstallGrubEFI "${args}";;
      "useraddnew") chrootUserAdd "${args}";;
      "userdelold") chrootUserDel "${args}";;
      "uservisudo") chrootUserSudo;;
      "usergivefini") chrootUserFini "${args}";;
      "setrootpassword") chrootSetRootPswd;;
    esac
  fi

}

checkNetwork() {

  if ! ping -4 -c 1 -w 5 archlinux.org &>/dev/null; then
    promptDiag "ERROR" "Network check failed!"
    exit 1
  fi

}

syncTime() {

  if ! timedatectl set-ntp true; then
    promptDiag "ERROR" "Unable to sync NTP"
  fi

}

pacmanConf() {

  local file="${1}"
  sed -i "/Color/s/^#//
    /TotalDownload/s/^#//
    /CheckSpace/s/^#//" \
    "$file"

}

syncPacman() {

  if ! pacman -Sy >/dev/null; then
    promptDiag "ERROR" "Unable to sync pacman"
  fi

}

checkMount() {

  if ! mount | grep -q " /mnt "; then
    haveMount=0
    return 1
  fi
  haveMount=1

}

checkVBox() {

  list=$(lspci | grep "VirtualBox G")
  if [ ! "${list}" ]; then
    isVBox=0
    return 1
  fi
  isVBox=1

}

installMenu() {

  if [ "${1}" = "" ]; then
    nextItem="${menuSetupBoot[1]}"
  else
    nextItem=${1}
  fi

  opt=()
  opt+=("${menuSetupKeys[1]}" " ${strOpt}")
  opt+=("${menuSetupFont[1]}" " ${strOpt}")
  opt+=("${menuSetupEdit[1]}" " ${strOpt}")
  opt+=("${menuSetupBoot[1]}" " ${strReq}")
  if [ ! "${haveMount}" == 1 ]; then
    opt+=("${menuPartDisks[1]}" " ${strOpt}")
    opt+=("${menuPartAssign[1]}" " ${strReq}")
    opt+=("${menuPartFormat[1]}" " ${strOpt}")
    opt+=("${menuPartMount[1]}" " ${strReq}")
  fi
  opt+=("${menuInstallMirror[1]}" " ${strRec}")
  opt+=("${menuInstallSelect[1]}" " ${strReq}")
  if [ "${needConfig}" == 1 ]; then
    opt+=("${menuConfSystem[1]}" " ${strReq}")
  fi
  if [ "${haveMount}" == 1 ]; then
    opt+=("${menuSysUnmount[1]}" " ${strOpt}")
  fi
  if [ "${needReboot}" == 1 ]; then
    opt+=("${menuSysReboot[1]}" " ${strRec}")
  fi

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuMain[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnQuit}" \
    3>&1 1>&2 2>&3); then

    case ${choice} in
      "${menuSetupKeys[1]}")
        preSetKeyMap
        nextItem="${menuSetupFont[1]}"
      ;;
      "${menuSetupFont[1]}")
        preSetFont
        nextItem="${menuSetupEdit[1]}"
      ;;
      "${menuSetupEdit[1]}")
        preSetEditor
        nextItem="${menuSetupBoot[1]}"
      ;;
      "${menuSetupBoot[1]}")
        preDetectBoot
        if [ "${haveMount}" == 1 ]; then
          nextItem="${menuInstallMirror[1]}"
        else
          nextItem="${menuPartDisks[1]}"
        fi
      ;;
      "${menuPartDisks[1]}")
        prePartDisk
        nextItem="${menuPartAssign[1]}"
      ;;
      "${menuPartAssign[1]}")
        prePartAssign
        nextItem="${menuPartFormat[1]}"
      ;;
      "${menuPartFormat[1]}")
        prePartFormat
        nextItem="${menuPartMount[1]}"
      ;;
      "${menuPartMount[1]}")
        prePartMount
        nextItem="${menuInstallMirror[1]}"
      ;;
      "${menuInstallMirror[1]}")
        if installMirrors; then
          syncPacman
        fi
        nextItem="${menuInstallSelect[1]}"
      ;;
      "${menuInstallSelect[1]}")
        if [ "${haveMount}" == 1 ]; then
          pkgSelectMenu
          nextItem="${menuConfSystem[1]}"
        else
          nextItem="${menuPartAssign[1]}"
        fi
      ;;
      "${menuConfSystem[1]}")
        pacmanConf "/mnt/etc/pacman.conf"
        configMenu
        nextItem="${menuSysReboot[1]}"
      ;;
      "${menuSysUnmount[1]}")
        postUnmount
      ;;
      "${menuSysReboot[1]}")
        postUnmount
        postReboot
      ;;
    esac
    installMenu "${nextItem}"
  fi

}

preSetKeyMap() {

  list=$(find /usr/share/kbd/keymaps/ -type f -printf "%f\n" | sort -V)
  opt=()
  for item in ${list}; do
    opt+=("${item%%.*}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuSetupKeys[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFKEYMAP}" \
    3>&1 1>&2 2>&3); then

    DEFKEYMAP="${choice}"
    loadkeys "${choice}"
  fi

}

preSetFont() {

  list=$(find /usr/share/kbd/consolefonts/*.psfu.gz -printf "%f\n")
  opt=()
  for item in ${list}; do
    opt+=("${item%%.*}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuSetupFont[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFVCFONT}" \
    3>&1 1>&2 2>&3); then

    DEFVCFONT="${choice}"
    eval "$(setfont "${choice}")"
  fi

}

preSetEditor() {

  opt=()
  opt+=("vi" "")
  opt+=("vim" "")
  opt+=("nano" "")

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuSetupEdit[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFEDITOR}" \
    3>&1 1>&2 2>&3); then

    EDITOR=${choice}
    DEFEDITOR=${choice}
    export EDITOR
  fi

}

preDetectBoot() {

  if [ -d "/sys/firmware/efi/efivars" ]; then
    bootType="EFI"
  else
    bootType="BIOS"
  fi

  promptDiag "${menuSetupBoot[0]}" "${bootType} boot detected..."

}

prePartDisk() {

  list=$(lsblk -dpnl -o NAME -e 7,11)
  opt=()
  for item in ${list}; do
    opt+=("${item}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartDisks[0]}" \
    --menu "\n${menuPartDisks[2]}" 0 0 0 "${opt[@]}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3) && \
    [ -b "${choice}" ]; then

    cfdisk "${choice}"
    prePartDisk
  fi

}

prePartAssign() {

  list=$(lsblk -pnl -o NAME -e 7,11)
  opt=()
  for item in ${list}; do
    if [[ "${item}"  == *[0-9] ]]; then
      opt+=("${item}" "")
    fi
  done

  if ! rootDev=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --menu "\nChoose '/' partition" 0 0 0 "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    promptDiag "ERROR" "You must assign a root partition!"
    return 1
  fi

  if bootDev=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --menu "\nChoose '/boot' partition" 0 0 0 "NONE" "" "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    if [ "${bootDev}" = "NONE" ]; then
      bootDev=
    fi
  else
    return 1
  fi

  if swapDev=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --menu "\nChoose 'SWAP' partition" 0 0 0 "NONE" "" "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    if [ "${swapDev}" = "NONE" ]; then
      swapDev=
    fi
  else
    return 1
  fi

  if homeDev=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --menu "\nChoose '/home' partition" 0 0 0 "NONE" "" "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    if [ "${homeDev}" = "NONE" ]; then
      homeDev=
    fi
  else
    return 1
  fi

  msg="Does this look correct?\n\n"
  if [ -n "${rootDev}" ]; then
    msg="${msg}${rootDev} to /\n"
  fi
  if [ -n "${bootDev}" ]; then
    msg="${msg}${bootDev} to /boot\n"
  fi
  if [ -n "${swapDev}" ]; then
    msg="${msg}${swapDev} to SWAP\n"
  fi
  if [ -n "${homeDev}" ]; then
    msg="${msg}${homeDev} to /home\n"
  fi

  if ! (whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --yesno "${msg}" 0 0 \
    3>&1 1>&2 2>&3); then

    prePartAssign
  fi

}

prePartFormat() {

  if (whiptail \
    --backtitle "${appName}" \
    --title "${menuPartFormat[0]}" \
    --defaultno \
    --yesno "Caution!\n\nYou are about to format the partitions\n\nALL DATA WILL BE LOST!" 0 0)
    then

    if [ ! "${bootDev}" = "" ]; then
      formatBoot boot "${bootDev}"
    fi

    if [ ! "${swapDev}" = "" ]; then
      formatSwap swap "${swapDev}"
    fi

    formatDevice root "${rootDev}"

    if [ ! "${homeDev}" = "" ]; then
      formatDevice home "${homeDev}"
    fi
  else
    return 1
  fi

}

formatBoot() {

  opt=()
  if [ "${bootType}" == "EFI" ]; then
    opt+=("fat32" "(EFI)")
  fi
  opt+=("ext2" "")
  opt+=("ext3" "")
  opt+=("ext4" "")

  if ! choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartFormat[0]}" \
    --menu "\nSelect filesystem for '${2}'" 0 0 0 "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    return 1
  fi

  clear
  case ${choice} in
    ext2)
      mkfs.ext2 "${2}"
    ;;
    ext3)
      mkfs.ext3 "${2}"
    ;;
    ext4)
      mkfs.ext4 "${2}"
    ;;
    fat32)
      mkfs.fat "${2}"
    ;;
  esac
  
}

formatSwap() {

  opt=()
  opt+=("SWAP" "")

  if ! choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartFormat[0]}" \
    --menu "\nSelect filesystem for '${2}'" 0 0 0 "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    return 1
  fi

  clear
  case ${choice} in
    SWAP)
      mkswap ${swapDev}
    ;;
  esac

}

formatDevice() {

  opt=()
  opt+=("ext2" "")
  opt+=("ext3" "")
  opt+=("ext4" "")
  opt+=("xfs" "")

  if ! choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartFormat[0]}" \
    --menu "\nSelect filesystem for '${2}'" 0 0 0 "${opt[@]}" \
    --default-item "ext4" \
    3>&1 1>&2 2>&3); then

    return 1
  fi

  clear
  case ${choice} in
    ext4)
      mkfs.ext4 "${2}"
    ;;
    ext3)
      mkfs.ext3 "${2}"
    ;;
    ext2)
      mkfs.ext2 "${2}"
    ;;
    xfs)
      mkfs.xfs -f "${2}"
    ;;
  esac
  shift
  
}

prePartMount() {

  msg="Mounted partitions\n\n"

  mount "${rootDev}" /mnt
  msg=${msg}"${rootDev} to /\n"

  mkdir /mnt/{boot,home} 2>/dev/null

  if [ ! "${bootDev}" = "" ]; then
    mount ${bootDev} /mnt/boot
    msg=${msg}"${bootDev} to /boot (${bootType})\n"
  fi

  if [ ! "${swapDev}" = "" ]; then
    swapon ${swapDev}
    msg=${msg}"${swapDev} to SWAP\n"
  fi

  if [ ! "${homeDev}" = "" ]; then
    mount ${homeDev} /mnt/home
    msg=${msg}"${homeDev} to /home\n"
  fi

  if (whiptail \
    --backtitle "${appName}" \
    --title "${menuPartMount[0]}" \
    --msgbox "${msg}" 0 0 \
    3>&1 1>&2 2>&3); then

    checkMount
  fi

}

installMirrors() {

  ${EDITOR} /etc/pacman.d/mirrorlist

}

pkgSelectMenu() {

  if [ "${1}" = "" ]; then
    nextItem="."
  else
    nextItem=${1}
  fi

  opt=()
  if [ ! "$installDone" == 1 ]; then
    opt+=("${menuPkgBase[1]}" " ${menuPkgBase[2]}")
    opt+=("${menuPkgMinimal[1]}" " ${menuPkgMinimal[2]}")
    opt+=("${menuPkgCustom[1]}" " ${PKG_LIST##*/}")
    opt+=("" "")
    opt+=("${menuKernelSelect[1]}" "")
    if [ "$havePkgs" == 1 ] && [ "$haveKernel" == 1 ]; then
      opt+=("" "")
      opt+=("${menuInstallPkgs[1]}" "")
    fi
  else
    opt+=("${menuInstallDone[1]}" "")
  fi

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuInstallSelect[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3); then

    case ${choice} in
      "${menuPkgBase[1]}")
        packages=("base")
        if [ "${#packages[@]}" -gt 0 ]; then
          havePkgs=1
          nextItem="${menuKernelSelect[1]}"
        fi
      ;;
      "${menuPkgMinimal[1]}")
        packages=("base" "base-devel" "vi" "sudo" \
          "xorg" "xorg-drivers" "xorg-apps" \
          "i3-gaps" "i3status" "i3lock-color" "xss-lock" \
          "ttf-dejavu" "dmenu" "surf" "rxvt-unicode" \
          "zsh" "tmux" "vim" "git" "openssh" \
          "man-db" "man-pages")

        if [ "${#packages[@]}" -gt 0 ]; then
          havePkgs=1
          nextItem="${menuKernelSelect[1]}"
        fi
      ;;
      "${menuPkgCustom[1]}")
        readCustomFile "$PKG_LIST"
        if [ "${#packages[@]}" -gt 0 ]; then
          havePkgs=1
          nextItem="${menuKernelSelect[1]}"
        fi
      ;;
      "${menuKernelSelect[1]}")
        if kernelSelectMenu; then
          haveKernel=1
          nextItem="${menuInstallPkgs[1]}"
        fi
      ;;
      "${menuInstallPkgs[1]}")
        clear
        if pacstrap /mnt --needed "${packages[@]}"; then
          packages=()
          havePkgs=0
          haveKernel=0
          installDone=1
          nextItem="${menuInstallDone[1]}"
        fi
      ;;
      "${menuInstallDone[1]}")
        needConfig=1
        return
      ;;
    esac
    pkgSelectMenu "${nextItem}"
  fi

}

kernelSelectMenu() {

  opt=()
  opt+=("${menuKernelLinux[1]}" "")
  opt+=("${menuKernelZen[1]}" "")
  opt+=("${menuKernelHardened[1]}" "")
  opt+=("${menuKernelLTS[1]}" "")

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuKernelSelect[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    3>&1 1>&2 2>&3); then

    case ${choice} in
      "${menuKernelLinux[1]}")
        packages+=("linux")
      ;;
      "${menuKernelLTS[1]}")
        packages+=("linux-lts")
      ;;
      "${menuKernelZen[1]}")
        packages+=("linux-zen")
      ;;
      "${menuKernelHardened[1]}")
        packages+=("linux-hardened")
      ;;
    esac
  else
    return 1
  fi

}

configMenu() {

  if [ "${1}" = "" ]; then
    nextItem="."
  else
    nextItem=${1}
  fi

  opt=()
  opt+=("${menuConfFstab[1]}" " ${strReq}")
  opt+=("${menuConfTime[1]}" " ${strRec}")
  opt+=("${menuConfLocale[1]}" " ${strRec}")
  opt+=("${menuConfKeymap[1]}" " ${strOpt}")
  opt+=("${menuConfFont[1]}" " ${strOpt}")
  opt+=("${menuConfHostname[1]}" " ${strReq}")
  opt+=("${menuConfDhcp[1]}" " ${strRec}")
  opt+=("${menuConfXdm[1]}" " ${strOpt}")
  opt+=("${menuConfBoot[1]}" " ${strRec}")
  opt+=("${menuConfUser[1]}" " ${strOpt}")
  opt+=("${menuConfRoot[1]}" " ${strReq}")

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfSystem[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3); then

    case ${choice} in
      "${menuConfFstab[1]}")
        postFstabGen
        nextItem="${menuConfTime[1]}"
      ;;
      "${menuConfTime[1]}")
        postSetTime
        nextItem="${menuConfLocale[1]}"
      ;;
      "${menuConfLocale[1]}")
        postSetLocale
        nextItem="${menuConfKeymap[1]}"
      ;;
      "${menuConfKeymap[1]}")
        postSetKeymap
        nextItem="${menuConfFont[1]}"
      ;;
      "${menuConfFont[1]}")
        postSetFont
        nextItem="${menuConfHostname[1]}"
      ;;
      "${menuConfHostname[1]}")
        postSetHostname
        nextItem="${menuConfDhcp[1]}"
      ;;
      "${menuConfDhcp[1]}")
        postEnableDHCP
        nextItem="${menuConfXdm[1]}"
      ;;
      "${menuConfXdm[1]}")
        postEnableXDM
        nextItem="${menuConfBoot[1]}"
      ;;
      "${menuConfBoot[1]}")
        installGrubMenu
        nextItem="${menuConfUser[1]}"
      ;;
      "${menuConfUser[1]}")
        postUserMenu
        nextItem="${menuConfRoot[1]}"
      ;;
      "${menuConfRoot[1]}")
        if postSetRootPswd; then
          needReboot=1
        fi
        nextItem="${menuConfRoot[1]}"
      ;;
    esac
    configMenu "${nextItem}"
  fi
}

execChroot() {

  shFile="$(basename "${0}")"
  cp "${0}" /mnt/root
  chmod 755 /mnt/root/"${shFile}"
  arch-chroot /mnt /root/"${shFile}" --chroot "${1}" "${2}"
  rm /mnt/root/"${shFile}"

}

postFstabGen() {
  
  if genfstab -U -p /mnt > /mnt/etc/fstab; then
    promptDiag "${menuConfFstab[0]}" "${menuConfFstab[2]}"
  fi
  
}

postSetTime() {

  list=$(find /mnt/usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  opt=()
  for item in ${list}; do
    opt+=("${item}" "")
  done

  if ! region=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuTimeRegion[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFTIMZON%%/*}" \
    3>&1 1>&2 2>&3); then

    return 1
  fi

  list=$(ls /mnt/usr/share/zoneinfo/"${region}"/)
  opt=()
  for item in ${list}; do
    opt+=("${item}" "")
  done

  if ! city=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuTimeCity[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFTIMZON##*/}" \
    3>&1 1>&2 2>&3); then

    return 1
  fi

  DEFTIMZON="${region}/${city}"
  ln -sf /usr/share/zoneinfo/"${DEFTIMZON}" /mnt/etc/localtime

  if (whiptail --backtitle "${appName}" \
    --title "${menuTimeUtc[0]}" \
    --yesno "${menuTimeUtc[2]}" 0 0) \
    then

    execChroot settimeutc
  else
    execChroot settimelocal
  fi

  if (whiptail \
    --backtitle "${appName}" \
    --title "${menuTimeSync[0]}" \
    --yesno "${menuTimeSync[2]}" 0 0)
    then

    clear
    execChroot enabletimesyncd
  fi

}

chrootSetTimeUTC() {

  clear
  hwclock --systohc --utc
  exit

}

chrootSetTimeLocal() {

  clear
  hwclock --systohc --localtime
  exit

}

chrootEnableTimesync() {

  clear
  systemctl enable systemd-timesyncd
  exit

}

postSetLocale() {

  list=$(ls /usr/share/i18n/locales)
  opt=()
  for item in ${list}; do
    opt+=("${item}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfLocale[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFLOCALE}" \
    3>&1 1>&2 2>&3); then

    clear
    echo "LANG=${choice}.UTF-8" > /mnt/etc/locale.conf
    echo "LC_COLLATE=C" >> /mnt/etc/locale.conf
    sed -i "/${choice}.UTF-8/s/^#//g" /mnt/etc/locale.gen

    execChroot setlocale
  fi

}

chrootSetLocale() {

  locale-gen
  exit

}

postSetKeymap() {

  list=$(find /usr/share/kbd/keymaps/ -type f -printf "%f\n" | sort -V)
  opt=()
  for item in ${list}; do
    opt+=("${item%%.*}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfKeymap[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFKEYMAP}" \
    3>&1 1>&2 2>&3); then

    echo "KEYMAP=${choice}" > /mnt/etc/vconsole.conf
  fi

}

postSetFont() {

  list=$(find /usr/share/kbd/consolefonts/*.psfu.gz -printf "%f\n")
  opt=()
  for item in ${list}; do
    opt+=("${item%%.*}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfFont[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFVCFONT}" \
    3>&1 1>&2 2>&3); then

    echo "FONT=${choice}" >> /mnt/etc/vconsole.conf
  fi

}

postSetHostname() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfHostname[0]}" \
    --inputbox "${menuConfHostname[1]}" 0 0 "archlinux" \
    3>&1 1>&2 2>&3); then

    echo -e "${input}" > /mnt/etc/hostname
    writeHostsFile "${input}" /mnt/etc/hosts
  fi

}

writeHostsFile() {

cat >"${2}" << EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${1}.localdomain  ${1}
EOF

}

postEnableDHCP() {

  clear
  if pacstrap /mnt --needed dhcpcd; then
    execChroot enabledhcpcd
  fi

}

chrootEnableDHCP() {

  systemctl enable dhcpcd
  exit

}

postEnableXDM() {

  clear
  if pacstrap /mnt --needed xorg-xdm; then
    postSetGui
    execChroot enablexdm
  fi

}

postSetGui() {

INIT="/mnt/etc/skel/.xinitrc"
cat >"${INIT}" <<EOF
#!/bin/bash

xrdb -merge .Xresources

xsetroot -solid grey20

exec i3
EOF
chmod +x "${INIT}"

XRES="/mnt/etc/skel/.Xresources"
cat >"${XRES}" <<EOF
URxvt*background: black
URxvt*foreground: gray
URxvt*font: xft:DejaVu Sans Mono:size=9
EOF

}

chrootEnableXDM() {

  systemctl enable xdm
  exit

}

installGrubMenu() {

  if [ "${1}" = "" ]; then
    nextItem="."
  else
    nextItem=${1}
  fi

  local opt=()
  if [ ! "${haveGrub}" == 1 ]; then
    opt+=("${menuGrubInstall[1]}" "")
    opt+=("${menuGrubEdit[1]}" " ${strOpt}")
    opt+=("${menuConfBoot[1]}" " ${strReq}")
  else
    opt+=("${menuGrubDone[1]}" "")
  fi

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuGrubInstall[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3); then

    case ${choice} in
      "${menuGrubInstall[1]}")
        installGrub
        nextItem="${menuConfBoot[1]}"
      ;;
      "${menuGrubEdit[1]}")
        ${EDITOR} /mnt/etc/default/grub
        if (whiptail \
          --backtitle "${appName}" \
          --title "${menuGrubEdit[0]}" \
          --yesno "Run grub-mkconfig again?" 0 0) then
          clear
          execChroot grubinstall
        fi
        nextItem="${menuConfBoot[1]}"
      ;;
      "${menuConfBoot[1]}")
        installGrubBoot
        haveGrub=1
        nextItem="${menuGrubDone[1]}"
      ;;
      "${menuGrubDone[1]}")
        return
      ;;
    esac

    installGrubMenu "${nextItem}"
  fi

}

installGrub() {

  clear
  pacstrap /mnt --needed grub
  
  if [ "${bootType}" == "EFI" ]; then
    pacstrap /mnt --needed efibootmgr
  fi

  clear
  execChroot grubinstall
  
}

chrootInstallGrub() {

  mkdir /boot/grub
  grub-mkconfig -o /boot/grub/grub.cfg
  exit

}

installGrubBoot() {

  disks=$(lsblk -d -p -n -l -o NAME -e 7,11)
  opt=()
  for disk in ${disks}; do
    opt+=("${disk}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfBoot[0]}" \
    --menu "${menuConfBoot[2]}" 0 0 0 "${opt[@]}" \
    --default-item "${bootDev}" \
    3>&1 1>&2 2>&3); then

    if [ "${bootType}" == "EFI" ]; then
      clear
      execChroot grubinstallefi "${choice}"
    else
      clear
      execChroot grubinstallbios "${choice}"
    fi
  fi

}

chrootInstallGrubBIOS() {

  if [ ! "${1}" = "NONE" ]; then
    grub-install --target=i386-pc --recheck "${1}"
  fi
  exit

}

chrootInstallGrubEFI() {

  if [ ! "${1}" = "NONE" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --recheck "${1}"

    if [ "${isVBox}" = 1 ]; then
      echo "\EFI\arch\grubx64.efi" > /boot/startup.nsh
    fi
  fi
  exit

}

postSetRootPswd() {

  clear
  execChroot setrootpassword

}

chrootSetRootPswd() {

  passwd root
  echo
  promptCli

}

postUserMenu() {

  opt=()
  opt+=("${menuUserAdd[1]}" " ")
  opt+=("${menuUserDel[1]}" " ")
  opt+=("${menuUserList[1]}" " ")
  opt+=("${menuUserSudo[1]}" " ")
  if [ -f "$CACHE_TGZ" ]; then
    opt+=("${menuUserFini[1]}" " ")
  fi


  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfUser[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3); then

    case $choice in
      "${menuUserAdd[1]}")
        postUserAdd
      ;;
      "${menuUserDel[1]}")
        postUserDel
      ;;
      "${menuUserList[1]}")
        postUserList
      ;;
      "${menuUserSudo[1]}")
        postUserSudo
      ;;
      "${menuUserFini[1]}")
        postUserFini
      ;;
    esac
    postUserMenu
  fi

}

postUserAdd() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserAdd[1]}" \
    --inputbox "Enter user name" 0 0 \
    3>&1 1>&2 2>&3); then
 
    clear
    execChroot useraddnew "${input}"
  fi

}

chrootUserAdd() {

  useradd -m "${1}"
  passwd "${1}"
  grpck
  echo
  promptCli ""

}

postUserDel() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserDel[1]}" \
    --inputbox "Enter user to delete" 0 0 \
    3>&1 1>&2 2>&3); then
 
    clear
    execChroot userdelold "${input}"
  fi

}

chrootUserDel() {

  userdel -r -f "${1}"
  grpck
  echo
  promptCli ""

}

postUserList() {

  #clear
  #execChroot userlistall

  local users
  users="$(awk -F: '{if ($3 >= 1000 && $3 <= 5000) { print $1 } }' /mnt/etc/passwd)"

  whiptail \
    --backtitle "${appName}" \
    --title "${menuUserList[0]}" \
    --msgbox "${users}" 0 0 \
    3>&1 1>&2 2>&3

}

postUserSudo() {

  clear
  pacstrap /mnt --needed vi sudo
  execChroot uservisudo

}

chrootUserSudo() {

  if EDITOR=${DEFEDITOR} visudo; then
    return
  fi

}

postUserFini() {

  local dest="/mnt/root/"
  local users=($(awk -F: '{if ($3 >= 1000 && $3 <= 5000) { print $1 } }' /mnt/etc/passwd))

  opt=()
  for user in "${users[@]}"; do
    opt+=("${user}" "")
  done

  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserFini[0]}" \
    --menu "${menuUserFini[2]}" 0 0 0 "${opt[@]}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3); then
    cp "$CACHE_TGZ" "$dest"
    execChroot usergivefini "$choice"
  fi

}

chrootUserFini() {

  local user="${1}"
  local src="/root/fini.tgz"
  local dest="/home/$user/"

  cp "$src" "$dest"
  chown "$user.$user" "${dest}${src##/*/}"
  rm "$src"

}

postUnmount() {

  clear
  umount -R /mnt
  haveMount=0

}

postReboot() {

  clear
  reboot
 
}

promptDiag() {

  local title="${1}"
  local msg="${2}"

  whiptail \
    --backtitle "${appName}" \
    --title "$title" \
    --msgbox "$msg" 0 0 \
    3>&1 1>&2 2>&3

}

promptCli() {

  [[ -n "$*" ]] && echo "$*"
  read -n1 -r -p "Press any key to continue..."

}

loadStrings() {

  appName="$(basename "${0}")"

  strOpt="  "
  strReq="**"
  strRec="  "

  menuMain=("Main Menu" "Install Arch Linux" "")

  menuSetupKeys=("Setup: Keyboard" "Set Keyboard Layout" "")
  menuSetupFont=("Setup: Font" "Set Console Font" "")
  menuSetupEdit=("Setup: Editor" "Set Text Editor" "")
  menuSetupBoot=("Setup: Boot" "Detect Boot Type" "")

  menuPartDisks=("Partition: Device" "Edit Partition Tables" "Select device")
  menuPartAssign=("Partition: Assign" "Assign Partitions" "Select mount point")
  menuPartFormat=("Partition: Format" "Format Partitions" "Select filesystem")
  menuPartMount=("Partition: Mount" "Mount Partitions" "Mount filesystems")

  menuInstallMirror=("Install: Mirrors" "Edit Software Mirrors" "")
  menuInstallSelect=("Install: Packages" "Install Packages" "Select software and kernel to install")

  menuPkgBase=("Base" "Select Base" "Just 'base'")
  menuPkgMinimal=("Desktop" "Select Desktop" "i3, urxvt, surf")
  menuPkgCustom=("Custom" "Select Custom" "${PKG_LIST}")

  menuKernelSelect=("Install: Kernel" "Select Kernel" "")
  menuKernelLinux=("Vanilla" "Install Standard Kernel" "linux")
  menuKernelZen=("Zen" "Install Zen Kernel" "linux-zen")
  menuKernelHardened=("Hardended" "Install Hardened Kernel" "linux-hardened")
  menuKernelLTS=("LTS" "Install LTS Kernel" "linux-lts")

  menuInstallPkgs=("Install: Pacstrap" "Install Software" "")
  menuInstallDone=("Install: Complete" "Installation Complete" "")

  menuConfSystem=("Install: Configure" "Configure New Install" "")

  menuConfFstab=("Configure: Fstab" "Generate Fstab" "Generated '/etc/fstab' file")
  menuConfTime=("Configure: Timezone" "Set System Time" "")
  menuTimeRegion=("Configure: Region" "Select Region" "")
  menuTimeCity=("Configure: City" "Select City" "")
  menuTimeUtc=("Configure: Hardware Clock" "Confirm Hardware Clock" "Is hardware clock set to UTC?")
  menuTimeSync=("Configure: Internet Time" "Confirm Internet Time" "Sync time with Internet?")

  menuConfLocale=("Configure: Locale" "Set System Locale" "")
  menuConfKeymap=("Configure: Keyboard" "Set Keyboard Layout" "")
  menuConfFont=("Configure: Font" "Set Console Font" "")
  menuConfHostname=("Configure: Hostname" "Set System Hostname" "")
  menuConfDhcp=("Configure: DHCP" "Enable DHCP Client" "")
  menuConfXdm=("Configure: XDM" "Enable Display Manager" "")

  menuConfBoot=("GRUB: Bootloader" "Install Bootloader" "Select device")
  menuGrubInstall=("GRUB: Install" "Install GRUB" "")
  menuGrubEdit=("GRUB: Config" "Edit GRUB Config" "")
  menuGrubDone=("GRUB: Install" "Installation Complete" "")

  menuConfUser=("Manage Users" "Manage User Accounts" "")
  menuUserAdd=("Add" "Add New User" "")
  menuUserDel=("Delete" "Delete Existing User" "")
  menuUserList=("User List" "List User Accounts" "")
  menuUserSudo=("Privileges" "Edit Sudoers File" "")
  menuUserFini=("Give Fini" "Give User Fini" "Select user")
  
  menuConfRoot=("Admin Password" "Set Root Password" "")

  menuSysUnmount=("Continue" "Unmount And Continue" "")
  menuSysReboot=("Reboot" "Reboot System" "")

  btnDone="Done"
  btnQuit="Quit"

}

parseArgs() {

  while (( "$#" )); do
    case ${1} in
      -h | --help)
        usage
        exit 0
      ;;
      -f | --fetch)
        getFini
        exit 0
      ;;
      -l | --list)
        PKG_LIST="${2}"
      ;;
      --pacstrap)
        if checkMount; then
          pkgStrap "${2}"
        fi
        exit 0
      ;;
      --chroot)
        chroot=1
        command=${2}
        args=${3}
      ;;
    esac
    shift
  done

}

usage() {

cat << EOF
usage: ${appName} [options] [args]

options:
  -h, --help            show help
  -l, --list FILE       load a custom package list
  -f, --fetch           fetch everything to current directory
  --pacstrap FILE       pacstrap any package list

EOF

}

readCustomFile() {

  packages=()
  while IFS= read -r line
  do
    packages+=("${line}")
  done < "${1}"

}

pkgStrap() {

  if readCustomFile "${1}"; then
    if pacstrap /mnt --needed "${packages[@]}"; then
      needConfig=1
    fi
  fi

}

getFini() {

  if curl -sLo "$CACHE_TGZ" "$FETCH_URL"; then
    tar xfz "$CACHE_TGZ" --strip 1 --exclude="*.md"
  fi

}

##############################################################################

loadStrings

parseArgs "$@"

main

exit 0

# vim: ft=sh ts=2 sw=0 et:
