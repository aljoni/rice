#!/bin/bash

# Aljoni's Arch Linux Rice Installer
#
# Version: 0.1
# Date:    2020/07/09

# ---------------------------------------------------------------------------- #
# Globals                                                                      #
# ---------------------------------------------------------------------------- #

CL_RED='\033[31m'
CL_ORANGE='\033[33m'
CL_YELLOW='\033[93m'
CL_GREEN='\033[32m'
CL_BLUE='\033[34m'
CL_CYAN='\033[36m'
CL_MAGENTA='\033[35m'
CL_PINK='\033[95m'
CL_GREY='\033[90m'
CL_GREY_BL='\033[90;05m'
CL_WHITE='\033[37m'
CL_RESET='\033[0m'
CL_CLEAR='\033[0J'
MS_ENTER="$CL_GREY[ENTER]$CL_RESET"

# ---------------------------------------------------------------------------- #
# Functions                                                                    #
# ---------------------------------------------------------------------------- #

function logo {
	printf "\n$CL_RED           .__\n"
	printf "$CL_YELLOW    _______|__| ____  ____\n"
	printf "$CL_GREEN    \\_  __ \\  |/ ___\\/ __ \\ \n"
	printf "$CL_CYAN     |  | \\/  \\  \\__\\  ___/\n"
	printf "$CL_BLUE     |__|  |__|\\___  >___  >\n"
	printf "$CL_PINK                   \\/    \\/\n\n"
	printf $CL_RESET
}

function log_tx {
	setterm -cursor off
	printf "$CL_WHITE[$CL_GREY_BL***$CL_RESET$CL_WHITE]$CL_RESET $1\r"
}

function log_ok {
	setterm -cursor on
	printf "$CL_CLEAR$CL_WHITE[$CL_GREEN"
	printf -- "---$CL_WHITE]$CL_RESET $1\n"
}

function log_wr {
	setterm -cursor on
	printf "$CL_CLEAR$CL_WHITE[$CL_ORANGE"
	printf "WRN$CL_WHITE]$CL_RESET $1\n"
}

function log_er {
	setterm -cursor on
	printf "$CL_CLEAR$CL_WHITE[$CL_RED"
	printf "ERR$CL_WHITE]$CL_RESET $1\n"
}

function input {
	printf "$CL_CLEAR$CL_WHITE[$CL_BLUE"
	printf "INP$CL_WHITE] $1 $CL_GREEN"
	read $2
	printf $CL_RESET
}

function input_pass {
	printf "$CL_CLEAR$CL_WHITE[$CL_BLUE"
	printf "INP$CL_WHITE] $1 $CL_RED"
	stty -echo
	CHARCOUNT=0
	while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
	do
	    # Enter - accept password
	    if [[ $CHAR == $'\0' ]] ; then
		break
	    fi
	    # Backspace
	    if [[ $CHAR == $'\177' ]] ; then
		if [ $CHARCOUNT -gt 0 ] ; then
		    CHARCOUNT=$((CHARCOUNT-1))
		    PROMPT=$'\b \b'
		    PASSWORD="${PASSWORD%?}"
		else
		    PROMPT=''
		fi
	    else
		CHARCOUNT=$((CHARCOUNT+1))
		PROMPT='*'
		PASSWORD+="$CHAR"
	    fi
	done
	eval "$2=$PASSWORD"
	stty echo
	printf "$CL_RESET\n"
}

function print_disks {
	lsblk | tail -n +2 | grep -v "loop\|├\|└" | awk '{print "[\033[90mDSK\033[0m] \033[93m" $1 " \033[90m-\033[32m " $4 "\033[0m"}' 
}

function cpu_vendor {
	cat /proc/cpuinfo | grep vendor_id | head -n 1 | cut -d ':' -f 2 | xargs echo -n
}

function gen_mirrorlist {
	curl -s "https://www.archlinux.org/mirrorlist/?country=GB&protocol=https&ip_version=4" | sed 's/#Server/Server/g' 2>/dev/null
}

function install_pac {
	log_tx "Installing $CL_GREY$1$CL_RESET..."
	pacman --noconfirm -S $1 &>/dev/null
	if [ $? -ne 0 ]; then
		log_er "Failed to install $CL_GREY$1$CL_RESET"
		cd ..
		rm -rf $1
		rm -f $1.tar.gz
		exit 1
	else
		log_ok "Installed $CL_GREY$1$CL_RESET"
	fi
}

function install_ucode {
	vendor=$(cpu_vendor)
	if [ $vendor == "GenuineIntel" ]; then
		install_pac intel-ucode
	elif [ $vendor == "AuthenticAMD" ]; then
		install_pac amd-ucode
	else
		log_er "Unknown CPU vendor"
		exit 1
	fi
}

function install_aur {
	log_tx "Downloading $CL_GREY$1$CL_RESET"
	curl -sLO https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz
	log_tx "Extracting $CL_GREY$1$CL_RESET"
	tar -xf $1.tar.gz &>/dev/null
	if [ $? -ne 0 ]; then
		log_er "Failed to extract $CL_GREY$1$CL_RESET"
		cd ..
		rm -rf $1
		rm -f $1.tar.gz
		exit 1
	fi
	cd $1
	log_tx "Builing package"
	makepkg -si &>/dev/null
	if [ $? -ne 0 ]; then
		log_er "Failed to build $CL_GREY$1$CL_RESET"
		cd ..
		rm -rf $1
		rm -f $1.tar.gz
		exit 1
	else
		log_ok "Install $CL_GREY$1$CL_RESET"
	fi
	cd ..
	rm -rf $1
	rm -f $1.tar.gz
}

# $1 - device
# $2 - swap size
function create_bios {
	log_tx "Partitioning for BIOS..."
	(
		printf "o\n"
		printf "n\n"
		printf "p\n"
		printf "1\n\n"
		printf "+$2M\n"
		printf "t\n"
		printf "82\n"
		printf "n\n"
		printf "p\n"
		printf "2\n\n\n"
		printf "w\n"
	) | fdisk /dev/$1 &>/dev/null
	log_ok "Partitioned disk for BIOS"
}

# $1 - device
# $2 - swap size
function create_uefi {
	log_tx "Partitioning for UEFI..."
	(
		printf "g\n"
		printf "n\n"
		printf "1\n\n"
		printf "+512M\n"
		printf "t\n"
		printf "1\n"
		printf "n\n"
		printf "2\n\n"
		printf "+$2M\n"
		printf "t\n"
		printf "2\n"
		printf "19\n"
		printf "n\n"
		printf "3\n\n\n"
		printf "w\n"
	) | fdisk /dev/$1 &>/dev/null
	log_ok "Partitioned disk for UEFI"
}

function set_large_font {
	install_pac terminus-font
	setfont ter-132n
}

# ---------------------------------------------------------------------------- #
# Stage One                                                                    #
# ---------------------------------------------------------------------------- #

function stage_one {
	clear
	logo

	pacman -Sy &>/dev/null

	input "Use large font (${CL_YELLOW}YES$CL_RESET or ${CL_YELLOW}NO$CL_RESET), followed by $MS_ENTER:" usr_large_font
	if [ ${usr_large_font,,} == "yes" ]; then
		set_large_font
	fi

	input "Type your keymap (${CL_GREY}e.g. uk$CL_RESET), followed by $MS_ENTER:" usr_keymap
	input "Type your region (${CL_GREY}e.g. Europe$CL_RESET), followed by $MS_ENTER:" usr_region
	input "Type your city (${CL_GREY}e.g. London$CL_RESET), followed by $MS_ENTER:" usr_city
	input "Type your locale (${CL_GREY}e.g. en_GB$CL_RESET), followed by $MS_ENTER:" usr_locale
	input "Type your mirror location (${CL_GREY}e.g. GB$CL_RESET), followed by $MS_ENTER:" usr_mirror_location
	print_disks
	input "Type target disk (${CL_GREY}e.g. sda$CL_RESET), followed by $MS_ENTER:" usr_disk
	input "Type swap size in MB, followed by $MS_ENTER:" usr_swap
	input "Type boot mode (${CL_YELLOW}BIOS$CL_RESET or ${CL_YELLOW}UEFI$CL_RESET), followed by $MS_ENTER:" usr_boot_type
	input "Type desired hostname, followed by $MS_ENTER:" usr_hostname
	input_pass "Type root password, followed by $MS_ENTER:" usr_root_pass

	# -- Setup clock
	log_tx "Updating clock..."
	timedatectl set-ntp true &>/dev/null
	log_ok "Clock updated"

	# -- Format disk
	if [ ${usr_boot_type,,} == "bios" ]; then
		create_bios $usr_disk $usr_swap

		log_tx "Formatting disk..."
		mkfs.ext4 "/dev/${usr_disk}2" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to format"
			exit 1
		fi
		log_ok "Formatted disk"

		log_tx "Creating swap..."
		mkswap "/dev/${usr_disk}1" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to create swap"
			exit 1
		fi
		swapon "/dev/${usr_disk}1" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to create swap"
			exit 1
		fi
		log_ok "Created swap"
	elif [ ${usr_boot_type,,} == "uefi" ]; then
		create_uefi $usr_disk $usr_swap

		log_tx "Formatting disk..."
		mkfs.fat -F32 "/dev/${usr_disk}1" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to format"
			exit 1
		fi
		mkfs.ext4 "/dev/${usr_disk}3" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to format"
			exit 1
		fi
		log_ok "Formatted disk"

		log_tx "Creating swap..."
		mkswap "/dev/${usr_disk}2" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to create swap"
			exit 1
		fi
		swapon "/dev/${usr_disk}2" &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to create swap"
			exit 1
		fi
		log_ok "Created swap"
	else
		log_er "Invalid boot type $CL_GREY$usr_boot_type$CL_RESET"
	fi

	# -- Mount disk
	log_tx "Mounting disk..."
	if [ ${usr_boot_type,,} == "bios" ]; then
		mount "/dev/${usr_disk}2" /mnt
		mkdir /mnt/boot
	else
		mount "/dev/${usr_disk}3" /mnt
		mkdir /mnt/boot
		mount "/dev/${usr_disk}1" /mnt/boot
	fi
	log_ok "Mounted disk"

	# -- Update mirrorlist
	log_tx "Updating mirrors..."
	printf "$(gen_mirrorlist $usr_mirror_location)" > /etc/pacman.d/mirrorlist
	log_ok "Updated mirrors"

	# -- Install base system
	log_tx "Installing base system..."
	pacstrap /mnt base linux base-devel linux-firmware grub vim &>/dev/null
	log_ok "Installed base system"

	# -- Generate fstab
	log_tx "Generating fstab..."
	genfstab -U /mnt >> /mnt/etc/fstab
	log_ok "Generated fstab"

	# -- Set locale
	log_tx "Setting locale..."
	printf "LANG=$usr_locale.UTF-8" > /mnt/etc/locale.conf
	sed -i "/^#$usr_locale/s/^#//" /mnt/etc/locale.gen
	log_ok "Set locale"

	# -- Set hostname
	log_tx "Setting hostname..."
	printf $usr_hostname > /mnt/etc/hostname
	printf "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.0.1\t$usr_hostname.localdomain  $usr_hostname" > /mnt/etc/hosts
	log_ok "Set hostname"

	# -- Set keymap
	log_tx "Setting keymap..."
	printf "KEYMAP=$usr_keymap" > /mnt/etc/vconsole.conf
	log_ok "Set keymap"

	# -- Set terminal font (large font)
	if [ ${usr_large_font,,} == "yes" ]; then
		log_tx "Setting large font..."
		printf "\nFONT=ter-132n" >> /mnt/etc/vconsole.conf
		log_ok "Set large font"
	fi

	# -- Prepare for stage two
	log_tx "Starting stage two..."
	cp rice.sh /mnt/rice.sh &>/dev/null
	mkdir /mnt/ricedata
	printf "$usr_region/$usr_city" > /mnt/ricedata/timezone
	printf "$usr_root_pass" > /mnt/ricedata/root_pass
	printf "$usr_disk" > /mnt/ricedata/disk
	printf "$usr_boot_type" > /mnt/ricedata/boot_type
	printf "$usr_large_font" > /mnt/ricedata/large_font
	chmod +x rice.sh
	arch-chroot /mnt "/rice.sh"
}

# ---------------------------------------------------------------------------- #
# Stage Two                                                                    #
# ---------------------------------------------------------------------------- #

function stage_two {
	log_ok "Stage two started"

	large_font=$(cat /ricedata/large_font)
	if [ ${large_font,,} == "yes" ]; then
		install_pac terminus-font
	fi

	log_tx "Setting timezone..."
	ln -sf "/usr/share/zoneinfo/$(cat /ricedata/timezone)" /etc/localtime
	hwclock --systohc &>/dev/null
	log_ok "Set timezone"

	log_tx "Generating locales..."
	locale-gen &>/dev/null
	log_ok "Generated locales"

	log_tx "Creating initramfs..."
	mkinitcpio -P &>/dev/null
	log_tx "Created initramfs"

	log_tx "Setting root password..."
	root_pass=$(cat /ricedata/root_pass)
	printf "$root_pass\n$root_pass\n" | passwd &>/dev/null
	log_ok "Set root password"

	log_tx "Installing bootloader..."
	boot_type=$(cat /ricedata/boot_type)
	disk=$(cat /ricedata/disk)
	if [ ${boot_type,,} == "bios" ]; then
		grub-install --target=i386-pc /dev/$disk &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to install bootloader"
			exit 1
		fi
	else
		install_pac efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB &>/dev/null
		if [ $? -ne 0 ]; then
			log_er "Failed to install bootloader"
			exit 1
		fi
	fi
	grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
	log_ok "Installed bootloader"

	log_tx "Cleaning up..."
	rm -rf /ricedata &>/dev/null
	rm -- "$0" &>/dev/null
	log_ok "Cleaned up"
}


# ---------------------------------------------------------------------------- #
# Entrypoint                                                                   #
# ---------------------------------------------------------------------------- #

if [[ -d "/ricedata" ]]; then
	stage_two
else
	stage_one
fi
