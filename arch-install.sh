#!/bin/sh
# Made by Abid Lohan

# Some functions

chrootcommands() {
    # Creating a script to execute all necessary arch-chroot commands within /mnt

    cat > /mnt/root/scripttemp.sh <<EOF
    ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    hwclock --systohc
    sed -i 's/#pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
    locale-gen
    echo LANG=pt_BR.UTF-8 >> /etc/locale.conf
    echo KEYMAP=br-abnt2 >> /etc/vconsole.conf
    echo archlinux >> /etc/hostname
    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1 localhost" >> /etc/hosts
    echo "127.0.0.1 archlinux.localdomain archlinux" >> /etc/hosts
    echo -e "\n" | pacman -S dosfstools os-prober mtools network-manager-applet networkmanager dialog sudo grub

    echo -e "\n-----------------------------------------"
    echo "[ ? ] Escolha uma senha para o root:"
    passwd

    echo -e "\n-----------------------------------------"
    echo "Criando usuário abidlohan..."
    useradd -m -g users -G wheel abidlohan
    echo -e "\n-----------------------------------------"
    echo "[ ? ] Escolha uma senha para abidlohan:"
    passwd abidlohan
    echo "abidlohan ALL=(ALL) ALL" >> /etc/sudoers

    grub-install --target=i386-pc --recheck /dev/sda
    cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
    grub-mkconfig -o /boot/grub/grub.cfg
    systemctl enable NetworkManager
EOF
    chmod +x /mnt/root/scripttemp.sh
    arch-chroot /mnt /root/scripttemp.sh
    rm /mnt/root/scripttemp.sh
}

afterinstall() {
    # Creating a script to install graphical interface after rebooting

    cat > /mnt/root/gnome.sh <<EOF
    #!/bin/sh

    echo -e "\n" | pacman -S xorg-server virtualbox-guest-utils mesa mesa-libgl gdm
    systemctl enable gdm
    echo -e "\n\n\n\n\n" | pacman -S gnome gnome-terminal nautilus gnome-tweaks gnome-control-center gnome-backgrounds adwaita-icon-theme
    reboot
EOF
    chmod +x /mnt/root/gnome.sh
}

# OS Instalation

# Date and time
timedatectl set-timezone America/Sao_Paulo

# Disk config
fdisk -l
echo -e "\n-----------------------------------------"
echo "[ ? ] Escolha o disco que deseja utilizar (/dev/sda por exemplo):"
read disco

fdisk -l $disco
echo -e "\n-----------------------------------------"
echo "[ ? ] Deseja criar uma partição SWAP? (y/n)"
read swapresponse

while ! echo $swapresponse | grep -i 'y\|n' > /dev/null 2>&1; do
	echo -e "\n-----------------------------------------"
	echo "Por favor, responda com y ou n apenas!"
	echo "[ ? ] Deseja criar uma partição SWAP? (y/n)"
	read swapresponse
done

if [ $swapresponse = "n" ] || [ $swapresponse = "N" ]; then
    echo "Você optou por não ter SWAP, prosseguindo..."
    (echo -e "o\nn\np\n\n\n\na\n"; sleep 2; echo "w") | fdisk $disco
    syspart="${disco}1"
else
    echo -e "\n-----------------------------------------"
    echo "[ ? ] Escolha o tamanho da SWAP (size{K,M,G,T,P}):"
    read swapsize

    (echo -e "o\nn\np\n\n\n+$swapsize\nt\n82\nn\np\n\n\n\na\n2\n"; sleep 2; echo "w") | fdisk $disco
    swappart="${disco}1"
    syspart="${disco}2"
fi

# Formating
mkfs.ext4 $syspart

if [ $swapresponse != "n" ] && [ $swapresponse != "N" ]; then
    mkswap $swappart
fi

# Mounting
mount $syspart /mnt

if [ $swapresponse != "n" ] && [ $swapresponse != "N" ]; then
    swapon $swappart
fi

echo "Partições configuradas!"

# Base linux packages
pacman -Syy
pacstrap /mnt base linux linux-firmware

# Finishing
genfstab -U /mnt >> /mnt/etc/fstab

chrootcommands
afterinstall

umount -R /mnt
reboot
