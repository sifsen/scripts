# more to be added, just lazy rn

PACKAGES=(
    "curl"
    "git"
    "vim"
    "htop"
    "python3"
    "build-essential"
    "fish"
    "fastfetch"
    "discord"
    "kitty"
    "plasma"
    "plasma-meta"
    "dolphin"
)

AUR_PACKAGES=(
    "vscodium-bin"
    "brave-bin"
    "cursor-bin"
    "spotify"
)

install() {
    echo "installing packages..."
    
    if ! command -v yay &> /dev/null; then
        echo "yay is not installed. installing yay..."
        
        sudo pacman -Syu --noconfirm make git
        
        git clone https://aur.archlinux.org/yay-git.git
        cd yay-git
        makepkg -si --noconfirm
        cd ..
        
        echo "yay installed successfully. proceeding..."
    else
        echo "yay is already installed. proceeding..."
    fi
    
    yay -S --noconfirm "${AUR_PACKAGES[@]}"

    sudo pacman -Syu --noconfirm "${PACKAGES[@]}"
}

install
