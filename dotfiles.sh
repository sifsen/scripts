REPO_URL="https://github.com/ohsenko/dotfiles.git"
TEMP_DIR="$HOME/temp_dotfiles"
CONFIG_DIR="$HOME/.config"

command_exists() {
    command -v "$1" &>/dev/null
}

if ! command_exists stow; then
    echo "Stow is not installed. Installing it..."
    if command_exists apt; then
        sudo apt update && sudo apt install stow -y
    elif command_exists pacman; then
        sudo pacman -S stow --noconfirm
    elif command_exists brew; then
        brew install stow
    else
        echo "Package manager not found. Please install 'stow' manually."
        exit 1
    fi
fi

if [ -d "$TEMP_DIR" ]; then
    echo "Dotfiles repository already exists in $TEMP_DIR. Pulling the latest changes..."
    cd "$TEMP_DIR" && git pull origin main
else
    echo "Cloning the dotfiles repository..."
    git clone "$REPO_URL" "$TEMP_DIR"
fi

cd "$TEMP_DIR" || { echo "Failed to navigate to cloned directory."; exit 1; }

echo "Stowing configuration files..."
for dir in */; do
    if [[ "$dir" == .git/ ]]; then
        continue
    fi
    stow --dir="$TEMP_DIR" --target="$HOME" "$dir"
done

echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Dotfiles setup is complete!"
