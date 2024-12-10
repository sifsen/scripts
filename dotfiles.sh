REPO_URL="git@github.com:ohsenko/dotfiles.git"
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
    elif command_exists dnf; then
        sudo dnf install stow
    else
        echo "package manager not found. please install 'stow' manually."
        exit 1
    fi
fi

if [ ! -d "$TEMP_DIR" ]; then
    echo "creating temporary directory $TEMP_DIR..."
    mkdir -p "$TEMP_DIR"
fi

if [ -d "$TEMP_DIR" ]; then
    echo "dotfiles repository already exists in $TEMP_DIR. pulling the latest changes..."
    cd "$TEMP_DIR" && git pull origin main
else
    echo "cloning the dotfiles repository..."
    git clone "$REPO_URL" "$TEMP_DIR"
fi

cd "$TEMP_DIR" || { echo "could not move into directory. exiting..."; exit 1; }

echo "stowing configuration files..."
for dir in */; do
    if [[ "$dir" == .git/ ]]; then
        continue
    fi
    stow --dir="$TEMP_DIR" --target="$HOME" "$dir"
done

echo "cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "dotfiles setup is complete!"
