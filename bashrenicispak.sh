#!/bin/bash
## Quick script for fesus to make league of legends working on EndlessOS using gentoo chroot
## Created by github.com/kreyren under GNUv2 licence

## TODO
# Make portage configuration for cabal that is not based on league of legends
# Make user-input optionable
## Set different /etc/resolv.conf on demand
# Fetch bobwya repo without that fucking layman

## Error handling
die() { echo "$*" 1>&2 ; exit 1; }
warn() { echo "$*" 1>&2 ; }

[[ $UID != "0" ]] && die "FATAL: This script has to be executed with root permission (using sudo for example)."

case $(hostname) in
  "endless")
      TargetDirectory="/var/mnt/gentoo/"
      my_user="fesus"
      ;;
  "dreamon")
      TargetDirectory="/mnt/GFEX/" # GentooFesusEXperiment
      my_user="kreyren"
      ;;
    *)
      printf "INPUT: Select your target directory:\nHINT: We will install gentoo in this directory, /mnt directory is recommended assuming gentoo system running in chroot environment."
      read TargetDirectory
      my_user="notkreyren"
esac

td="${TargetDirectory}"

## Sanitization
### Required to check on some linux-based distros that doesn't have GNU tools.
### TODO: Export using script if not present.
sanity_checks() {
  [ ! -x $(command -v mount) ] && die "FATAL: Command 'mount' not executable"
  [ ! -x $(command -v chroot) ] && die "FATAL: Command 'chroot' not executable"
  [ ! -x $(command -v wget) ] && die "FATAL: Command 'wget' not executable"
  [ ! -x $(command -v mv) ] && die "FATAL: Command 'mv' not executable"
  [ ! -x $(command -v grep) ] && die "FATAL: Command 'grep' not executable"
  [ ! -x $(command -v sed) ] && die "FATAL: Command 'sed' not executable"
  [ -z ${td} ] && die "FATAL:"
}; sanity_checks

install_gentoo() {
  ## Make Directory
  if [[ ! -d ${td} ]]; then
    mkdir -p ${td} || die "FATAL: Unable to make new directory in ${td}."
  elif [[ -d ${td} ]]; then
    printf "INFO: Directory ${td} is present.\n"
  fi

  ## Export gentoo on ${td} if not present
  if [[ ! -e ${td}/etc/portage ]]; then
    ## Fetch definitions for file, why not use current like exherbo's current naming and make my job easier..
    ### TODO: use curl if present to getch requried variable?
    if [[ ! -e ${td}/gentoo_info ]]; then
      wget https://gentoo.osuosl.org/releases/amd64/autobuilds/latest-stage3-amd64.txt -O ${td}/gentoo_info || die "FATAL: Unable to fetch definitions for gentoo tarbar name."
    elif [[ -e ${td}/gentoo_info ]]; then
      printf "INFO: file ${td}/gentoo_info is present\n"
    fi

    ## Definitions for files and shit
    gentoo_tarbar="http://distfiles.gentoo.org/releases/amd64/autobuilds/$(cat ${td}/gentoo_info | grep -o "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z/stage3-amd64-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z.tar.xz")"
      gt="${gentoo_tarbar}"
    gentoo_file_name="$(cat ${td}/gentoo_info | grep -o "stage3-amd64-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z.tar.xz")"
      qfn="${gentoo_file_name}" # Doesn't work for some reason..

    ## Actual fetch
    if [[ ! -e "${td}/${gentoo_file_name}" ]]; then
      wget ${gt} -P ${td} || die "FATAL: unable to fetch tarbar"
    elif [[ -e ${td}/${gentoo_file_name} ]]; then
      printf "INFO: Tarbar ${td}/${gentoo_file_name} is present\n"
    fi
    printf "INFO: Extracting ${gentoo_file_name} tarbar" && tar -xpf "${td}/${gentoo_file_name}" --directory="${td}" || die "FATAL: Unable to extract tarbar"
    rm "${td}/${gentoo_file_name}" || warn "ERROR: Unable to remove ${td}/${gentoo_file_name}"## Sanitized rm
  elif [[ -e ${td}/etc/portage ]]; then
    printf "INFO: Gentoo is already extracted.\n"
  fi

  ## Make mount points
  if [[ $(mount | grep -o "${td}" -m 1) != "${td}" ]]; then
     mount --rbind /dev ${td}/dev || die "FATAL: Unable to mount /dev as --rbind"
     mount --make-rslave ${td}/dev || die "FATAL: Unable to mount /dev as --make-rslave"
     mount -t proc /proc ${td}/proc || die "FATAL: Unable to mount /proc"
     mount --rbind /sys ${td}/sys || die "FATAL: Unable to mount /sys as --rbind"
     mount --make-rslave ${td}/sys || die "FATAL: Unable to mount /sys as --make-rslave"
     mount --rbind /tmp ${td}/tmp || die "FATAL: Unable to mount /tmp as --rbind"
     printf "INFO: Mount points for ${td}/{dev,proc,sys,tmp} has been configured\n"

  elif [[ $(mount | grep -o "${td}" -m 1) == "${td}" ]]; then
    printf "INFO: Mount points are mounted\n"
  fi

  ## Configure ${td}/etc/resolv.conf
  if [[ $(sed -n 1p ${td}/etc/resolv.conf) != "nameserver 1.1.1.1"  ]]; then
    printf "nameserver 1.1.1.1\nnameserver1.0.0.1\nnameserver 2606:4700:4700::1111\nnameserver 2606:4700:4700::1001" > ${td}/etc/resolv.conf || die "FATAL: Unable to make ${td}/etc/resolv.conf configuration"
  elif [[ $(sed -n 1p /etc/resolv.conf) != "nameserver 1.1.1.1"  ]]; then
    printf "INFO: ${td}etc/resolv.conf is configured\n"
  fi

  ## Chrooting
  ### Adapting Argent Linux binhost
  if [[ $(cat ${td}/etc/portage/make.conf | grep -o "PORTAGE_BINHOST="http://pkgwork.argentlinux.io/argentwork/binhost/x64/"") != "PORTAGE_BINHOST="http://pkgwork.argentlinux.io/argentwork/binhost/x64/"" ]]; then
    printf "PORTAGE_BINHOST="http://pkgwork.argentlinux.io/argentwork/binhost/x64/"" >> ${td}/etc/portage/make.conf
  elif [[ $(cat ${td}/etc/portage/make.conf | grep -o "PORTAGE_BINHOST="http://pkgwork.argentlinux.io/argentwork/binhost/x64/"") == "PORTAGE_BINHOST="http://pkgwork.argentlinux.io/argentwork/binhost/x64/"" ]]; then
    printf "INFO: Argent linux binhost is configured, thanks Nox! <3"
  fi
  ### Sync gentoo repository
  #### TODO: Sanitize
  printf "INFO: Syncing gentoo repository." && chroot ${td} emerge --sync --quiet || die "FATAL: Unable to sync gentoo repository"
  ### Creating user account
  if [[ $(chroot ${td} cat /etc/group | grep -o "${my_user}" -m 1) != "${my_user}" ]]; then
    chroot ${td} useradd -m -G users,wheel,audio -s /bin/bash ${my_user} || die "FATAL: Unable to make new user on chroot"
  elif [[ $(chroot ${td} cat /etc/group | grep -o "${my_user}" -m 1) == "${my_user}" ]]; then
    printf "INFO: Account ${my_user} is present in chroot\n"
  fi
  ### Configure Xorg
  xauth extract ${td}/home/${my_user}/.Xauthority $(hostname)/unix:0 && printf "FIXME: .Xauthority has been exported." || die "FATAL+FIXME: Unable to export .Xauthority"
  #### Install Xorg if not present already
  printf "INFO: Installing xorg if not present already\n" && chroot ${td} emerge --noreplace --getbinpkg="y" xorg-server && printf "INFO: xorg-server is present\n" || die "FATAL: Unable to install xorg-server"
  #### Add localhost into chroot
  printf "INFO: Adding localhost into xhost\n" && chroot ${td} env XAUTHORITY="/home/${my_user}/.Xauthority" xhost +localhost || die "FATAL: Unable to add localhost into xhost"
  ### Fix permission of /home/${my_user}/.Xauthority
  printf "INFO: Transfering ownership of /home/${my_user}/.Xauthority to ${my_user}\n" && chroot ${td} bash -c "chown ${my_user}:${my_user} /home/${my_user}/.Xauthority" || die "FATAL: Unable to transfer ownership of /home/${my_user}/.Xauthority to ${my_user}"
  ### Creating /home/${my_user}/Downloads
  if [[ ! -e ${td}/home/${my_user}/Downloads ]]; then
    chroot ${td} su ${my_user} -c "mkdir /home/${my_user}/Downloads" || die "FATAL: Unable to make directory in /home/${my_user}/Downloads"
  elif [[ -e ${td}/home/${my_user}/Downloads ]]; then
    printf "INFO: Directory ${td}/home/${my_user}/Downloads is present\n"
  fi
}

prepare_for_gaming() {
  ### Fetch bobwya repository
  ## Configure bobwya repository which is recommended for wine
  if [[ ! -e ${td}/etc/portage/repos.conf/bobwya.conf && "$(cat ${td}/etc/portage/repos.conf/bobwya.conf)" != "$(printf "[bobwya]\nlocation = /usr/bobwya-repo/\nsync-type = git\nsync-uri = git@github.com:bobwya/bobwya.git\nauto-sync = yes")" ]]; then
    chroot ${td} printf "[bobwya]\nlocation = /usr/bobwya-repo/\nsync-type = git\nsync-uri = git@github.com:bobwya/bobwya.git\nauto-sync = yes" > /etc/portage/repos.conf/bobwya.conf || die "FATAL: Unable to write into ${td}/etc/portage/repos.conf/bobwya.conf\n"
  elif [[ -e ${td}/etc/portage/repos.conf/bobwya.conf && "$(cat ${td}/etc/portage/repos.conf/bobwya.conf)" == "$(printf "[bobwya]\nlocation = /usr/bobwya-repo/\nsync-type = git\nsync-uri = git@github.com:bobwya/bobwya.git\nauto-sync = yes")" ]]; then
    printf "INFO: Bobwya repository has been configured./n"
  fi
  ## Check if layout.conf is present for bobwya
  if [[ ! -e ${td}/usr/layman-repo ]]; then
    chroot ${td} mkdir -p /usr/layman-repo/metadata && printf "INFO: Created new directory in /usr/layman-repo/metadata" || die "FATAL: Unable to create a new directory in /usr/layman-repo/metadata.\n"
    chroot ${td} printf "masters = gentoo" > /usr/layman-repo/matadata/layout.conf || die "FATAL: Unable to parse instructions in layout.conf of bobwya repository."
  elif [[ -e ${td}/usr/layman-repo && $(cat ${td}/usr/layman-repo/metadata/layout.conf) != "masters = gentoo" ]]; then
    chroot ${td} printf "masters = gentoo" > ${td}/usr/layman-repo/metadata/layout.conf || die "FATAL: Unable to update layout.conf of bobwya repository."
  fi
  ### Check if /home/${my_user}/Games/ is present
  if [[ ! -e ${td}/home/${my_user}/Games/ ]]; then
     chroot ${td} su ${my_user} -c "mkdir -p /home/${my_user}/Games/" || die "FATAL: Unable to make new game directory on chroot"
  elif [[ -e ${td}/home/${my_user}/Games/ ]]; then
    printf "INFO: Directory ${td}/home/${my_user}/Games/ is present\n"
  fi
  ### Check if wine is present, else install it
  if [[ ! -h ${td}/usr/bin/wine ]]; then
    chroot ${td} emerge =app-emulation/wine-staging-9999::bobwya --quiet || die "FATAL: Unable to fetch wine"
  elif [[ -h ${td}/usr/bin/wine ]]; then
    printf "INFO: wine is present\n"
  elif [[ -e ${td}/usr/bin/wine ]]; then
    die "FATAL: File ${td}/usr/bin/wine is not expected to be regular file, symlink is expected."
  fi
  ### Get winetricks
  if [[ ! -e ${td}/usr/bin/winetricks ]]; then
    printf "INFO: Installing winetricks\n" && chroot ${td} emerge =app-emulation/winetricks-9999 --quiet || die "FATAL: Unable to enoch merge winetricks."
  elif [[ -e ${td}/usr/bin/winetricks ]]; then
    printf "INFO: Winetricks is present."
  fi
}

fetch_leagueoflegends() {
  ## Fetching the game
  ### Creating /home/${my_user}/Downloads
  if [[ ! -e ${td}/home/${my_user}/Downloads ]]; then
    chroot ${td} su ${my_user} -c "mkdir /home/${my_user}/Downloads" || die "FATAL: Unable to make directory in /home/${my_user}/Downloads"
  elif [[ -e ${td}/home/${my_user}/Downloads ]]; then
    printf "INFO: Directory ${td}/home/${my_user}/Downloads is present\n"
  fi
  ### Check if $HOME/Games/LeagueOfLegends is present
  if [[ ! -e ${td}/home/${my_user}/Games/ ]]; then
     chroot ${td} su ${my_user} -c "mkdir -p /home/${my_user}/Games/" || die "FATAL: Unable to make new game directory on chroot"
  elif [[ -e ${td}/home/${my_user}/Games/ ]]; then
    printf "INFO: Directory ${td}/home/${my_user}/Games/ is present\n"
  fi
  ### Download the game
  if [[ ! -e ${td}/home/${my_user}/Downloads/lol_installer.exe ]]; then
     chroot ${td} su ${my_user} -c "wget https://riotgamespatcher-a.akamaihd.net/releases/live/installer/deploy/League%20of%20Legends%20installer%20EUNE.exe -O /home/${my_user}/Downloads/lol_installer.exe" || die "FATAL: Unable to fetch LeagueOfLegends installer"
  elif [[ -e ${td}/home/${my_user}/Downloads/lol_installer.exe ]]; then
    printf "INFO: lol_installer.exe is present\n"
  fi
  ### Install the game
  if [[ ! -e ${td}/home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe ]]; then
     printf "WARNING: DO NOT CHANGE DEFAULT PATH OF LEAGUE OF LEGENDS INSTALLATION!!"
     chroot ${td} su ${my_user} -c "env XAUTHORITY="/home/${my_user}/.Xauthority" WINEDEBUG="fixme-all" WINEPREFIX="/home/${my_user}/Games/LeagueOfLegends" wine /home/${my_user}/Downloads/lol_installer.exe" || die "FATAL: Unable to install LeagueOfLegends"
    printf "SUCCESS: LeagueOfLegends was installed.\n"
  elif [[ -e ${td}/home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe ]]; then
    printf "INFO: LeagueOfLegends is installed.\n"
  fi
  ## Run the game
  if [[ -e ${td}/home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe ]]; then
     chroot ${td} su ${my_user} -c "env XAUTHORITY="/home/${my_user}/.Xauthority" WINEDEBUG="fixme-all" WINEPREFIX="/home/${my_user}/Games/LeagueOfLegends" wine /home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe" || die "FATAL: Unable to run LeagueOfLegends"
  elif [[ ! -e ${td}/home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe ]]; then
    printf "FATAL: This error should never happend.\n"
  fi
}

fetch_cabal() {
  ## Fetching the game
  ### Download the game
  if [[ ! -e ${td}/home/${my_user}/Downloads/co_installer.exe ]]; then
     chroot ${td} su ${my_user} -c "wget http://cdn2.playthisgame.com/Setup/11132014_US_Setup.exe -O /home/${my_user}/Downloads/co_installer.exe" || die "FATAL: Unable to fetch CabalOnline installer"
  elif [[ -e ${td}/home/${my_user}/Downloads/co_installer.exe ]]; then
    printf "INFO: co_installer.exe is present\n"
  fi
  ### Get workarounds
  if [[ $(chroot ${td} su -c "${my_user} env XAUTHORITY="/home/${my_user}/.Xauthority" WINEPREFIX="/home/${my_user}/Games/CABAL" winetricks list-installed | grep -o "glsl=disabled" -m 1") != "glsl=disabled" ]]; then
    chroot ${td} su ${my_user} -c "env XAUTHORITY="/home/${my_user}/.Xauthority" WINEPREFIX="/home/${my_user}/Games/CABAL" winetricks glsl=disabled" && printf "INFO: Disabling GLSL for CABAL\n" || die "FATAL: Unable to disable glsl for CABAL."
  elif [[ $(chroot ${td} su -c "${my_user} env XAUTHORITY="/home/${my_user}/.Xauthority" WINEPREFIX="/home/${my_user}/Games/CABAL" winetricks list-installed | grep -o "glsl=disabled" -m 1") == "glsl=disabled" ]]; then
    printf "INFO: GLSL is disabled."
  fi
  ### Install the game
  if [[ ! -e ${td}/home/${my_user}/Games/CABAL/drive_c/Program\ Files\ \(x86\)/CABAL\ Online\ \(NA\ \-\ Global\)/cabal.exe ]]; then
     printf "WARNING: DO NOT CHANGE DEFAULT PATH OF CABAL ONLINE INSTALLATION!!"
     chroot ${td} su ${my_user} -c "env XAUTHORITY="/home/${my_user}/.Xauthority" WINEDEBUG="fixme-all" WINEPREFIX="/home/${my_user}/Games/CABAL" wine /home/${my_user}/Downloads/co_installer.exe" || die "FATAL: Unable to install CABAL Online."
    printf "SUCCESS: CABAL Online was installed.\n"
  elif [[ -e ${td}/home/${my_user}/Games/LeagueOfLegends/drive_c/Riot\ Games/League\ of\ Legends/LeagueClient.exe ]]; then
    printf "INFO: CABAL Online is installed.\n"
  fi
  ## Run the game
  if [[ -e ${td}/home/${my_user}/Games/CABAL/drive_c/Program\ Files\ \(x86\)/CABAL\ Online\ \(NA\ \-\ Global\)/cabal.exe ]]; then
     chroot ${td} su ${my_user} -c "env XAUTHORITY="/home/${my_user}/.Xauthority" WINEDEBUG="fixme-all" WINEPREFIX="/home/${my_user}/Games/CABAL" wine /home/${my_user}/Games/CABAL/drive_c/Program\ Files\ \(x86\)/CABAL\ Online\ \(NA\ \-\ Global\)/cabal.exe" || die "FATAL: Unable to run CABAL online"
  elif [[ ! ${td}/home/${my_user}/Games/CABAL/drive_c/Program\ Files\ \(x86\)/CABAL\ Online\ \(NA\ \-\ Global\)/cabal.exe ]]; then
    printf "FATAL: This error should never happend.\n"
  fi
}

configure_portage_for_lol_and_cabal() {
  ### Configuring package.use
  if [[ ! -e ${td}/etc/portage/package.use/00-KGGWIGCH.use ]]; then
    ## Check if ${td}/etc/portage/package.use/ is present
    if [[ ! -e ${td}/etc/portage/package.use/ ]]; then
      printf "INFO: Creating ${td}/etc/portage/package.use/\n" && mkdir ${td}/etc/portage/package.use/ || die "FATAL: Unable to create ${td}/etc/portage/package.use/ directory"
    elif [[ -e ${td}/etc/portage/package.keywords/ ]]; then
      printf "INFO: Directory ${td}/etc/portage/package.keywords/ is already present"
    fi
    ## Configure everything
    printf "INFO: Configuring ${td}/etc/portage/package.use/00-KGGWIGCH.use\n" && printf "# required by >=sys-auth/polkit-0.110\nsys-auth/polkit consolekit\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXcursor-1.2.0 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXext-1.3.4 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXfixes-5.0.3-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXrandr-1.5.2 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXi-1.7.9-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[X]\n# required by wine-staging (argument)\n>=x11-libs/libXxf86vm-1.1.4-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[alsa]\n# required by wine-staging (argument)\n>=media-libs/alsa-lib-1.1.8 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[fontconfig]\n# required by wine-staging (argument)\n>=media-libs/fontconfig-2.13.0-r4 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[lcms]\n# required by wine-staging (argument)\n>=media-libs/lcms-2.9 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[ncurses]\n# required by wine-staging (argument)\n>=sys-libs/ncurses-6.1-r2 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[nls]\n# required by wine-staging (argument)\n>=sys-devel/gettext-0.19.8.1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[png]\n# required by wine-staging (argument)\n>=media-libs/libpng-1.6.37 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=net-libs/gnutls-3.6.7 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo\n# required by wine-staging (argument)\n>=sys-apps/attr-2.4.47-r2 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[truetype]\n# required by wine-staging (argument)\n>=media-libs/freetype-2.9.1-r3 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[udisks]\n# required by wine-staging (argument)\n>=sys-apps/dbus-1.12.12-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[xcomposite]\n# required by wine-staging (argument)\n>=x11-libs/libXcomposite-0.4.5 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[xml]\n# required by wine-staging (argument)\n>=dev-libs/libxml2-2.9.9-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[xml]\n# required by wine-staging (argument)\n>=dev-libs/libxslt-1.1.32 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[gecko]\n# required by wine-staging (argument)\n>=app-emulation/wine-gecko-2.47-r1 abi_x86_32\n# required by sys-auth/polkit-0.115-r3::gentoo[consolekit]\n# required by sys-fs/udisks-2.8.1::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[udisks]\n# required by wine-staging (argument)\n>=sys-auth/consolekit-1.2.1 policykit\n# required by sys-auth/consolekit-1.2.1::gentoo\n# required by sys-auth/polkit-0.115-r3::gentoo[consolekit]\n# required by sys-fs/udisks-2.8.1::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[udisks]\n# required by wine-staging (argument)\n>=dev-libs/glib-2.58.3 dbus\n# required by dev-lang/spidermonkey-52.9.1_pre1::gentoo\n# required by sys-auth/polkit-0.115-r3::gentoo\n# required by sys-auth/consolekit-1.2.1::gentoo[policykit]\n>=dev-lang/python-2.7.15:2.7 sqlite\n# required by dev-libs/libxslt-1.1.32::gentoo[crypt]\n# required by dev-lang/vala-0.42.7::gentoo\n# required by gnome-base/dconf-0.30.1::gentoo\n# required by dev-libs/glib-2.58.3::gentoo[dbus]\n# required by dev-libs/libgudev-232::gentoo\n# required by virtual/libgudev-232::gentoo\n# required by sys-fs/udisks-2.8.1::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[udisks]\n# required by wine-staging (argument)\n>=dev-libs/libgcrypt-1.8.3 abi_x86_32\n# required by dev-libs/libgcrypt-1.8.3::gentoo\n# required by dev-libs/libxslt-1.1.32::gentoo[crypt]\n# required by dev-lang/vala-0.42.7::gentoo\n# required by gnome-base/dconf-0.30.1::gentoo\n# required by dev-libs/glib-2.58.3::gentoo[dbus]\n# required by dev-libs/libgudev-232::gentoo\n# required by virtual/libgudev-232::gentoo\n# required by sys-fs/udisks-2.8.1::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[udisks]\n# required by wine-staging (argument)\n>=dev-libs/libgpg-error-1.36 abi_x86_32\n# required by media-libs/freetype-2.9.1-r3::gentoo\n# required by media-libs/fontconfig-2.13.0-r4::gentoo\n# required by app-eselect/eselect-fontconfig-1.1-r1::gentoo\n>=sys-libs/zlib-1.2.11-r2 abi_x86_32\n# required by x11-libs/libXrandr-1.5.2::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libX11-1.6.7 abi_x86_32\n# required by dev-libs/elfutils-0.173-r1::gentoo[bzip2]\n# required by virtual/libelf-3::gentoo\n# required by media-libs/mesa-18.3.6::gentoo[gallium,llvm,video_cards_radeonsi,-video_cards_r600,video_cards_radeon,-opencl]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=app-arch/bzip2-1.0.6-r11 abi_x86_32\n# required by net-libs/gnutls-3.6.7::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=dev-libs/libtasn1-4.13 abi_x86_32\n# required by net-dns/libidn2-2.1.1a-r1::gentoo\n# required by net-libs/gnutls-3.6.7::gentoo[idn]\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=dev-libs/libunistring-0.9.10 abi_x86_32\n# required by net-libs/gnutls-3.6.7::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=dev-libs/nettle-3.4.1 abi_x86_32\n# required by dev-libs/nettle-3.4.1::gentoo[gmp]\n# required by net-libs/gnutls-3.6.7::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=dev-libs/gmp-6.1.2 abi_x86_32\n# required by net-libs/gnutls-3.6.7::gentoo[idn]\n# required by app-emulation/wine-staging-4.8::gentoo[ssl]\n# required by wine-staging (argument)\n>=net-dns/libidn2-2.1.1a-r1 abi_x86_32\n# required by media-libs/fontconfig-2.13.0-r4::gentoo\n# required by app-eselect/eselect-fontconfig-1.1-r1::gentoo\n>=dev-libs/expat-2.2.6 abi_x86_32\n# required by media-libs/fontconfig-2.13.0-r4::gentoo\n# required by app-eselect/eselect-fontconfig-1.1-r1::gentoo\n>=sys-apps/util-linux-2.33-r1 abi_x86_32\n# required by app-emulation/faudio-19.03::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[faudio]\n# required by wine-staging (argument)\n>=media-libs/libsdl2-2.0.9 abi_x86_32\n# required by x11-libs/libXrandr-1.5.2::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libXrender-0.9.10-r1 abi_x86_32\n# required by x11-libs/libXext-1.3.4::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/pkgconfig-1 abi_x86_32\n# required by virtual/pkgconfig-1::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=dev-util/pkgconf-1.5.4 abi_x86_32\n# required by sys-devel/gettext-0.19.8.1::gentoo\n# required by dev-libs/elfutils-0.173-r1::gentoo[nls]\n# required by virtual/libelf-3::gentoo\n# required by media-libs/mesa-18.3.6::gentoo[gallium,llvm,video_cards_radeonsi,-video_cards_r600,video_cards_radeon,-opencl]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/libintl-0-r2 abi_x86_32\n# required by sys-devel/gettext-0.19.8.1::gentoo\n# required by dev-libs/elfutils-0.173-r1::gentoo[nls]\n# required by virtual/libelf-3::gentoo\n# required by media-libs/mesa-18.3.6::gentoo[gallium,llvm,video_cards_radeonsi,-video_cards_r600,video_cards_radeon,-opencl]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/libiconv-0-r2 abi_x86_32\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/opengl-7.0-r2 abi_x86_32\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=media-libs/mesa-18.3.6 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libxshmfence-1.3-r1 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libXdamage-1.1.5 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libxcb-1.13.1 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libdrm-2.4.97 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo[llvm,video_cards_radeonsi,-video_cards_r600,-opencl,video_cards_radeon]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=sys-devel/llvm-7.1.0 abi_x86_32\n# required by x11-libs/libdrm-2.4.97::gentoo[video_cards_intel]\n# required by media-libs/mesa-18.3.6::gentoo[-video_cards_i965,video_cards_intel,-video_cards_i915]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libpciaccess-0.14 abi_x86_32\n# required by sys-devel/llvm-7.1.0::gentoo[libffi]\n# required by media-libs/mesa-18.3.6::gentoo[llvm,video_cards_radeonsi,-video_cards_r600,-opencl,video_cards_radeon]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/libffi-3.0.13-r1 abi_x86_32\n# required by virtual/libffi-3.0.13-r1::gentoo\n# required by sys-devel/llvm-7.1.0::gentoo[libffi]\n# required by media-libs/mesa-18.3.6::gentoo[llvm,video_cards_radeonsi,-video_cards_r600,-opencl,video_cards_radeon]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=dev-libs/libffi-3.2.1 abi_x86_32\n# required by media-libs/mesa-18.3.6::gentoo[gallium,llvm,video_cards_radeonsi,-video_cards_r600,video_cards_radeon,-opencl]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/libelf-3 abi_x86_32\n# required by virtual/libelf-3::gentoo\n# required by media-libs/mesa-18.3.6::gentoo[gallium,llvm,video_cards_radeonsi,-video_cards_r600,video_cards_radeon,-opencl]\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=dev-libs/elfutils-0.173-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=virtual/glu-9.0-r2 abi_x86_32\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=media-libs/glu-9.0.0-r1 abi_x86_32\n# required by app-emulation/wine-staging-4.8::gentoo[jpeg]\n# required by wine-staging (argument)\n>=virtual/jpeg-0-r3:0 abi_x86_32\n# required by virtual/jpeg-0-r3::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[jpeg]\n# required by wine-staging (argument)\n>=media-libs/libjpeg-turbo-1.5.3-r2 abi_x86_32\n# required by x11-libs/libxcb-1.13.1::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=dev-libs/libpthread-stubs-0.4-r1 abi_x86_32\n# required by x11-libs/libxcb-1.13.1::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libXau-1.0.9 abi_x86_32\n# required by x11-libs/libxcb-1.13.1::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-libs/libXdmcp-1.1.3 abi_x86_32\n# required by x11-libs/libxcb-1.13.1::gentoo\n# required by media-libs/mesa-18.3.6::gentoo\n# required by virtual/opengl-7.0-r2::gentoo\n# required by media-libs/glu-9.0.0-r1::gentoo\n# required by virtual/glu-9.0-r2::gentoo\n# required by app-emulation/wine-staging-4.8::gentoo[opengl]\n# required by wine-staging (argument)\n>=x11-base/xcb-proto-1.13 abi_x86_32\n# required by x11-misc/xdg-utils-1.1.3-r1::gentoo\n# required by app-emulation/winetricks-20170823::gentoo\n# required by winetricks (argument)\n>=app-text/xmlto-0.0.28-r1 text\n# required for ntlm_auth\napp-emulation/wine-staging samba# required by app-emulation/wine-staging-4.8::gentoo[samba]\n# required by wine-staging (argument)\n>=net-fs/samba-4.8.6-r2 winbind" > ${td}/etc/portage/package.use/00-KGGWIGCH.use
    elif [[ -e ${td}/etc/portage/package.use/00-KGGWIGCH.use ]]; then
      printf "INFO: ${td}/etc/portage/package.use/00-KGGWIGCH.use is configured\n"
  fi

  ### Configuring package.keywords
  if [[ ! -e ${td}/etc/portage/package.keywords/00-KGGWIGCH.keywords ]]; then
    ## Check if ${td}/etc/portage/package.keywords/ is present
    if [[ ! -e ${td}/etc/portage/package.keywords/ ]]; then
      printf "INFO: Creating ${td}/etc/portage/package.keywords/\n" && mkdir ${td}/etc/portage/package.keywords/ || die "FATAL: Unable to create ${td}/etc/portage/package.keywords/ directory"
    elif [[ ! -e ${td}/etc/portage/package.keywords/ ]]; then
      printf "INFO: Directory ${td}/etc/portage/package.keywords/ is already present"
    fi
    printf "# required by app-emulation/wine-staging-4.8::gentoo[faudio]\n# required by wine-staging (argument)\n=app-emulation/faudio-19.03 ~amd64\n# required by app-emulation/wine-staging-4.8::gentoo[mono]\n# required by wine-staging (argument)\n=app-emulation/wine-mono-4.8.3 ~amd64\n# required by wine-staging (argument)\n=app-emulation/wine-staging-4.8 ~amd64\napp-emulation/winetricks **\n# required to workaround https://bugs.winehq.org/show_bug.cgi?id=47198\napp-emulation/wine-staging **\n# required by app-emulation/wine-staging-9999::bobwya\n# required by =app-emulation/wine-staging-9999::bobwya (argument)\n=app-eselect/eselect-wine-1.5.5 ~amd64" > ${td}/etc/portage/package.keywords/00-KGGWIGCH.keywords
  elif [[ -e ${td}/etc/portage/package.use/00-KGGWIGCH.use ]]; then
    printf "INFO: ${td}/etc/portage/package.use/00-KGGWIGCH.use is configured\n"
  fi
}

wipe_portage_configuration() { # wipe /etc/portage/package.{use,keywords}
  if [[ -e ${td}/etc/portage/ ]]; then
    chroot ${td} rm -r /etc/portage/package.use /etc/portage/package.keywords && printf "INFO: Configuration in /etc/portage/package.{use,keywords} has been wiped." || die "FATAL: Unable to wipe configuration in /etc/portage/package.{use,keywords}"
    configure_portage
  elif [[ ! -e ${td}/etc/portage/ ]]; then
    die "FATAL: Unable to wipe $([ -z ${td} ] && printf "<TARGET_DIRECTORY>" || printf "${td}")/etc/portage, No such file or directory."
  fi
}

case $1 in
  --get-gentoo)
    install_gentoo && chroot ${td} /bin/bash
    ;;
  --leagueoflegends|--lol)
    install_gentoo
    configure_portage_for_lol_and_cabal
    prepare_for_gaming
    fetch_leagueoflegends
    ;;
  --cabal|--co)
    install_gentoo
    configure_portage_for_lol_and_cabal
    prepare_for_gaming
    fetch_cabal
    ;;
  --fesus|--noob) # Special usecase
    wipe_portage_configuration
    configure_portage_for_lol_and_cabal
    prepare_for_gaming
    ;;
  --update)
    ## WARN: Has to be one line since rest of the file will be changed during this process
    if [[ ! -e /tmp/BASHRENICISPAK ]]; then
      mkdir /tmp/BASHRENICISPAK && printf "INFO: Creating new temporary directory in /tmp/BASHRENICISPAK that is going to be used for update.\n" || die "FATAL: Unable to create a new temporary directory in /tmp/BASHRENICISPAK.\n"
    elif [[ -e /tmp/BASHRENICISPAK ]]; then
      printf "INFO: Temporary directory in /tmp/BASHRENICISPAK exists\n"
    fi

  printf "INFO: Fetching bashrenicispak..\n" && wget https://raw.githubusercontent.com/Kreyrenicis/bashrenicistrispak/master/bashrenicispak.sh -O /tmp/BASHRENICISPAK/bashrenicispak.sh && printf "INFO: bashrenicispak has been fetched\n" || die "FATAL: Unable to fetch bashrenicispak.\n"

    if [[ -e /usr/bin && ! -e /ostree ]]; then
      mv /tmp/BASHRENICISPAK/bashrenicispak.sh /usr/bin/bashrenicispak && printf "SUCCESS: BASHRENICISPAK has been suceessfully updated!\n" || die "FATAL: Unable to update bashrenicispak from temporary directory.\n"

    elif [[ -e /ostree ]]; then
      if [[ ! -e /var/usrlocal/bin ]]; then
        mkdir /var/usrlocal/bin -p && printf "INFO: Created new directory in /var/usrlocal/bin\n" || die "FATAL: Unable to make new directory in /var/usrlocal/bin.\n"
        mv /tmp/BASHRENICISPAK/bashrenicispak.sh /var/usrlocal/bin && printf "SUCCESS: BASHRENICISPAK has been suceessfully updated!\n" || die "FATAL: Unable to update bashrenicispak from temporary directory.\n"
      elif [[ -e /var/usrlocal/bin ]]; then
        printf "INFO: Directory /var/usrlocal/bin exists\n"
                mv /tmp/BASHRENICISPAK/bashrenicispak.sh /var/usrlocal/bin && printf "SUCCESS: BASHRENICISPAK has been suceessfully updated!\n" || die "FATAL: Unable to update bashrenicispak from temporary directory.\n"
      fi
    fi
    ;;
  --help|*)
    printf "BASHRENICISPAK!\n\nUSAGE:\n--leagueoflegends    To install League Of Legends\n--cabal    To install CABAL Online.\n\nCreated by github.com/kreyren under GNUv2\n"
    ;;
esac
