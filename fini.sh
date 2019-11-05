#!/usr/bin/env bash

# fini.sh
# a simple menu-driven Arch Linux install script

# EDIT DEFAULTS
DEFKEYMAP="us"              # KEYBOARD LAYOUT
DEFLOCALE="en_US"           # LOCALE
DEFVCFONT="default8x16"     # CONSOLE FONT
DEFTIMZON="America/Chicago" # TIMEZONE CITY\REGION
DEFEDITOR="vim"             # TEXT EDITOR

runDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
pkgList="$runDir/packages.txt"
getUrl="https://github.com/jeffmhubbard/fini/archive/master.tar.gz"

main() {

  if [ "${chroot}" = "1" ]; then

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
      "userlistall") chrootUserList;;
      "uservisudo") chrootUserSudo;;
      "setrootpassword") chrootSetRootPswd;;
    esac
  else

    if checkNetwork; then

      # detect if new root is mounted
      checkMount

      # sync time with ntp
      syncTime

      # tweak pacman config
      pacmanConf

      # main menu
      mainMenu
    else

      exit 1
    fi
  fi

}

# Check for internet connection
checkNetwork() {

  hasGateway() {

    gateway=$(ip r | grep default | awk 'NR==1 {print $3}')
    if ! ping -q -w 1 -c 1 "${gateway}" &> /dev/null; then
      return 1
    fi

  }

  hasInternet() {

    if ! ping -c 1 -w 5 archlinux.org &>/dev/null; then 
      return 1
    fi

  }

  if ! hasGateway || ! hasInternet; then
    if (whiptail \
      --backtitle "${appName}" \
      --title "ERROR" \
      --msgbox "no internet connection" 0 0 \
      3>&1 1>&2 2>&3)
      then
      exit 1
    fi
  fi

}

# Spruce up pacman for the install
pacmanConf() {

  conf="/etc/pacman.conf"
  sed -i "/Color/s/^#//" ${conf}
  sed -i "/TotalDownload/s/^#//" ${conf}
  sed -i "/CheckSpace/s/^#//" ${conf}

}

checkMount() {

  if ! mount | grep " /mnt "; then
    haveMount=0
    return 1
  fi
  haveMount=1

}

# Sync time
syncTime() {

  if ! timedatectl set-ntp true; then
    winComplete "Unable to sync NTP"
  fi

}

mainMenu() {

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
  fi
  opt+=("${menuPartAssign[1]}" " ${strReq}")
  if [ ! "${haveMount}" == 1 ]; then
    opt+=("${menuPartFormat[1]}" " ${strOpt}")
    opt+=("${menuPartMount[1]}" " ${strReq}")
  fi
  opt+=("${menuInstallMirror[1]}" " ${strRec}")
  opt+=("${menuInstallSync[1]}" " ${strOpt}")
  opt+=("${menuInstallSelect[1]}" " ${strReq}")
  if [ "${needConfig}" == 1 ]; then
    opt+=("" "")
    opt+=("${menuConfSystem[1]}" " ${strReq}")
  fi
  opt+=("" "")
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
    3>&1 1>&2 2>&3)
    then

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
          nextItem="${menuPartAssign[1]}"
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
        if [ "${haveMount}" == 1 ]; then
          nextItem="${menuInstallMirror[1]}"
        else
          nextItem="${menuPartFormat[1]}"
        fi
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
        installMirrors
        nextItem="${menuInstallSync[1]}"
      ;;
      "${menuInstallSync[1]}")
        installSyncDB
        nextItem="${menuInstallSelect[1]}"
      ;;
      "${menuInstallSelect[1]}")
        if [ "${haveMount}" == 1 ]; then
          pkgSelectMenu
          nextItem="${menuConfSystem[1]}"
        else
          nextItem="${menuPartMount[1]}"
        fi
      ;;
      "${menuConfSystem[1]}")
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
    mainMenu "${nextItem}"
  fi

}

# Set the keyboard layout
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
    3>&1 1>&2 2>&3)
    then

    DEFKEYMAP="${choice}"
    loadkeys "${choice}"
  fi

}

## Set the console font
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
    3>&1 1>&2 2>&3)
    then

    DEFVCFONT="${choice}"
    eval "$(setfont "${choice}")"
  fi

}

## Set text editor
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
    3>&1 1>&2 2>&3)
    then

    EDITOR=${choice}
    DEFEDITOR=${choice}
    export "${EDITOR?}"
  fi

}

# Check for UEFI
preDetectBoot() {

  if [ -d "/sys/firmware/efi/efivars" ]; then
    bootType="EFI"
  else
    bootType="BIOS"
  fi

  winComplete "${menuSetupBoot[0]}" "${bootType} boot detected..."

}

# Partition disks
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
    [ -b "${choice}" ]
    then

    cfdisk "${choice}"
    prePartDisk
  fi

}

# Set mountpoints
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
    3>&1 1>&2 2>&3)
    then

    return 1
  fi

  if bootDev=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuPartAssign[0]}" \
    --menu "\nChoose '/boot' partition" 0 0 0 "NONE" "" "${opt[@]}" \
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

    prePartAssign
  fi

}

# Format the partitions
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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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

# Mount the file systems
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
    3>&1 1>&2 2>&3)
  then

    checkMount
  fi

}

# Select the mirrors
installMirrors() {

  ${EDITOR} /etc/pacman.d/mirrorlist

}

# Sync pacman database
installSyncDB() {

  if pacman -Sy >/dev/null; then
    winComplete "${menuInstallSync[0]}" "Package database synced..."
  fi

}

# Install the base packages
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
    opt+=("${menuPkgCustom[1]}" " ${pkgList##*/}")
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
    3>&1 1>&2 2>&3)
    then

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
          "xorg" "xorg-drivers" "xorg-apps" "xorg-xdm" \
          "i3-wm" "i3status" "i3lock-color" "xss-lock" \
          "ttf-dejavu" "dmenu" "surf" "rxvt-unicode" \
          "zsh" "tmux" "vim" "git" "openssh" \
          "man-db" "man-pages")

        if [ "${#packages[@]}" -gt 0 ]; then
          havePkgs=1
          nextItem="${menuKernelSelect[1]}"
        fi
      ;;
      "${menuPkgCustom[1]}")
        readCustomFile "$pkgList"
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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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
    winComplete "${menuConfFstab[0]}" "${menuConfFstab[2]}"
  fi
  
}

# Set the time
postSetTime() {

  list=$(find /mnt/usr/share/zoneinfo -type d -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
  opt=()
  for item in ${list}; do
    opt+=("${item}" "")
  done

  if ! region=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuTimeRegion[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${DEFTIMZON%%/*}" \
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
    then

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

# Generate system locale
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
    3>&1 1>&2 2>&3)
    then

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

# Set the keyboard layout
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
    3>&1 1>&2 2>&3)
    then

    echo "KEYMAP=${choice}" > /mnt/etc/vconsole.conf
  fi

}

# Set the console font
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
    3>&1 1>&2 2>&3)
    then

    echo "FONT=${choice}" >> /mnt/etc/vconsole.conf
  fi

}

# Set the hostname
postSetHostname() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfHostname[0]}" \
    --inputbox "${menuConfHostname[1]}" 0 0 "archlinux" \
    3>&1 1>&2 2>&3)
    then

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

# Enable DHCP client
postEnableDHCP() {

  if (whiptail \
    --backtitle "${appName}" \
    --title "${menuConfDhcp[0]}" \
    --yesno "${menuConfDhcp[1]}" 0 0)
    then

    clear
    pacstrap /mnt --needed dhcpcd
    execChroot enabledhcpcd
  fi

}

chrootEnableDHCP() {

  systemctl enable dhcpcd
  exit

}

# Enable XDM
postEnableXDM() {

  if (whiptail \
    --backtitle "${appName}" \
    --title "${menuConfXdm[0]}" \
    --yesno "${menuConfXdm[1]}" 0 0)
    then

    clear
    if pacstrap /mnt xorg-xdm; then
      postSetGui
    fi
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

# Install bootloader
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
    3>&1 1>&2 2>&3)
    then

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
    3>&1 1>&2 2>&3)
  then

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

    isvbox=$(lspci | grep "VirtualBox G")
    if [ "${isvbox}" ]; then
      echo "\EFI\arch\grubx64.efi" > /boot/startup.nsh
    fi
  fi
  exit

}

# Set root password
postSetRootPswd() {

  clear
  execChroot setrootpassword

}

chrootSetRootPswd() {

  passwd root
  tuiComplete

}

# Manage user accounts
postUserMenu() {

  opt=()
  opt+=("${menuUserAdd[1]}" " ${menuUserAdd[2]}")
  opt+=("${menuUserDel[1]}" " ${menuUserDel[2]}")
  opt+=("${menuUserList[1]}" " ${menuUserList[2]}")
  opt+=("${menuUserSudo[1]}" " ${menuUserSudo[2]}")


  if choice=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuConfUser[0]}" \
    --menu "" 0 0 0 "${opt[@]}" \
    --default-item "${nextItem}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3)
    then

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

# Add new user
postUserAdd() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserAdd[1]}" \
    --inputbox "Enter user name:" 0 0 \
    3>&1 1>&2 2>&3)
    then
 
    clear
    execChroot useraddnew "${input}"
  fi

}

chrootUserAdd() {

  useradd -m "${1}"
  passwd "${1}"
  grpck
  tuiComplete "User ${1} added"

}

# Delete user
postUserDel() {

  if input=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserDel[1]}" \
    --inputbox "Enter user to delete" 0 0 \
    3>&1 1>&2 2>&3)
    then
 
    clear
    execChroot userdelold "${input}"
  fi

}

chrootUserDel() {

  userdel -r -f "${1}"
  grpck
  tuiComplete "User ${1} deleted"

}

# List users
postUserList() {

  clear
  execChroot userlistall

}

chrootUserList() {

  echo "Users:"
  awk -F: '{if ($3 >= 1000 && $3 <= 5000) { print $1 } }' /etc/passwd
  tuiComplete

}

# Run visudo
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

# Give $user fini
postUserFini() {

  opt=("$(awk -F: '{if ($3 >= 1000 && $3 <= 5000) { print $1 } }' /etc/passwd)")

  if user=$(whiptail \
    --backtitle "${appName}" \
    --title "${menuUserFini[0]}" \
    --menu "${menuUserFini[2]}" 0 0 0 "${opt[@]}" \
    --cancel-button "${btnDone}" \
    3>&1 1>&2 2>&3)
    then

    giveFini "$user"
  fi

}

# Unmount 
postUnmount() {

  clear
  umount -R /mnt
  haveMount=0

}

postReboot() {

  clear
  reboot
 
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

  cacheTo="/tmp/fini.tgz"
  if curl -sLo "$cacheTo" "$getUrl"; then
    tar xfz "$cacheTo" --strip 1
  fi

}

giveFini() {

  local user=${1}
  local src="/tmp/fini.tgz"
  local dest="/home/$user"
  if [ -f "$src" ] && [ -d "$dest" ]; then
    install -C -m 755 -o "$user" -g "$user" "$src" "$dest"
  fi

}

winComplete() {

  whiptail \
    --backtitle "${appName}" \
    --title "$1" \
    --msgbox "$2" 0 0 \
    3>&1 1>&2 2>&3

}

tuiComplete() {

  [[ -n "$*" ]] && echo "$*"
  read -n1 -r -p "Press any key to continue..."

}

loadStrings() {

  appName="$(basename "${0}")"

  strOpt="(OPT)"
  strReq="(REQ)"
  strRec="(REC)"

  # Menu entries (title, menu, extra)
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
  menuInstallSync=("Install: Sync DB" "Update Software Database" "")
  menuInstallSelect=("Install: Packages" "Install Packages" "Select software and kernel to install")

  menuPkgBase=("Base" "Select Base" "Just 'base'")
  menuPkgMinimal=("Desktop" "Select Desktop" "i3, urxvt, surf")
  menuPkgCustom=("Custom" "Select Custom" "${pkgList}")

  menuKernelSelect=("Install: Kernel" "Select Kernel" "")
  menuKernelLinux=("Vanilla" "Install Standard Kernel" "linux")
  menuKernelZen=("Zen" "Install Zen Kernel" "linux-zen")
  menuKernelHardened=("Hardended" "Install Hardened Kernel" "linux-hardened")
  menuKernelLTS=("LTS" "Install LTS Kernel" "linux-lts")

  menuInstallPkgs=("Install: Pacstrap" "Install Software" "")
  menuInstallDone=("Install: Complete" "Installation Complete" "")

  menuConfSystem=("Install: Configure" "Configure New Install" "")

  menuConfFstab=("Configure: Fstab" "Generate Filesystem Table" "Fstab generated...")
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
  menuUserList=("List" "List User Accounts" "")
  menuUserSudo=("Privileges" "Edit Sudoers File" "")
  menuUserFini=("Fini" "Give User Fini" "")
  
  menuConfRoot=("Admin Password" "Set Root Password" "")

  menuSysUnmount=("Continue" "Unmount And Continue" "")
  menuSysReboot=("Reboot" "Reboot System" "")

  # Buttons
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
        pkgList="${2}"
      ;;
      --pacstrap)
        if checkMount; then
          pkgStrap "${2}"
        fi
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

##############################################################################

loadStrings

parseArgs "$@"

main

exit 0

# vim: ft=sh ts=2 sw=0 et:
