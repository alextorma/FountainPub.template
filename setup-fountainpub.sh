#!/bin/bash

# One-time setup for fountainpub auto-export
# Run this once after cloning: ./setup-fountainpub.sh
# This script will self-destruct after setup

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "🔧 Setting up fountainpub auto-export (one-time setup)..."

# Check if Node.js and npm are available and try to install fountainpub
FOUNTAINPUB_READY=false

if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo "⚠️  Node.js and npm are not detected."
    echo ""
    echo "📋 To install Node.js:"
    echo "  • Visit https://nodejs.org/ and download the latest version"
    echo "  • Or use a package manager:"
    echo "    - macOS: brew install node"
    echo "    - Linux: sudo pacman -S nodejs npm (or your distro's equivalent)"
    echo "    - Windows: winget install OpenJS.NodeJS"
    echo ""
    echo "📝 After installing Node.js, install fountainpub:"
    echo "  npm install -g fountainpub"
else
    echo "✅ Node.js and npm detected"

    # Try to install fountainpub globally
    if ! command -v fountainpub &>/dev/null; then
        echo "📦 Installing fountainpub..."
        if npm install -g fountainpub 2>/dev/null; then
            echo "✅ fountainpub installed successfully"

            # Verify fountainpub installation
            if command -v fountainpub &>/dev/null; then
                echo "✅ fountainpub is ready"
                FOUNTAINPUB_READY=true
            else
                echo "⚠️  fountainpub installed but not found in PATH"
                echo "📝 Please ensure your npm global bin directory is in your PATH"
            fi
        else
            echo "⚠️  Failed to install fountainpub automatically"
            echo ""
            echo "📝 Manual installation required:"
            echo "  npm install -g fountainpub"
            echo ""
            echo "💡 If you get permission errors, try:"
            echo "  sudo npm install -g fountainpub"
            echo ""
            echo "🔧 Or configure npm to use a different directory:"
            echo "  mkdir ~/.npm-global"
            echo "  npm config set prefix '~/.npm-global'"
            echo "  echo 'export PATH=~/.npm-global/bin:\$PATH' >> ~/.bashrc"
            echo "  source ~/.bashrc"
            echo "  npm install -g fountainpub"
        fi
    else
        echo "✅ fountainpub is already installed"
        FOUNTAINPUB_READY=true
    fi
fi

# Apply the repository's Git configuration (hooks and aliases)
echo "🪝 Configuring Git hooks directory and aliases..."

# Set up the hooks path in the local gitconfig with absolute path
# This ensures VS Code can find the hooks directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_PATH="$REPO_ROOT/.fountainpub.d/hooks"

# git config core.hooksPath "$HOOKS_PATH"
echo "🔗 Linking hooks in $HOOKS_PATH to .git/hooks"
cd "$REPO_ROOT/.git/hooks"
for hook in "$HOOKS_PATH"/*; do
    if [ -f "$hook" ]; then
        hook_name=$(basename "$hook")
        if [ -f "${hook_name}.sample" ]; then
            echo "ℹ️  Backing up existing sample hook: ${hook_name}.sample"
            mv "${hook_name}.sample" "original_${hook_name}.sample"
        fi
        ln -sf "../../.fountainpub.d/hooks/$hook_name" "$hook_name"
        echo "🔗 Linked $hook_name"
    fi
done
cd "$REPO_ROOT"

# Apply the configuration
git config --local include.path "../.fountainpub.d/.gitconfig-local"
echo "✅ Applied local gitconfig include"

echo "✅ Setup complete!"
echo ""

if [ "$FOUNTAINPUB_READY" = true ]; then
    echo "🎉 Your Git workflow is fully enhanced:"
    echo "  git commit  # Automatically runs fountainpub locally via post-commit hook"
    echo "  git push    # Starts background daemon for ongoing sync monitoring"
    echo ""
    echo "🔍 Check sync status: git sync-status"
    echo "🚀 Manual start: git sync-start"
    echo "⏹️  Manual stop: git sync-stop"
else
    echo "⚠️  Git hooks are configured, but fountainpub needs manual installation:"
    echo ""
    echo "📋 To complete setup:"
    echo "  1. Install Node.js from https://nodejs.org/ (if not already installed)"
    echo "  2. Run: npm install -g fountainpub"
    echo "  3. Verify: fountainpub --version"
    echo ""
    echo "💡 After fountainpub is installed, your Git workflow will be fully enhanced:"
    echo "  git commit  # Automatically runs fountainpub locally via post-commit hook"
    echo "  git push    # Starts background daemon for ongoing sync monitoring"
    echo ""
    echo "🔍 Check sync status: git sync-status"
    echo "🚀 Manual start: git sync-start"
    echo "⏹️  Manual stop: git sync-stop"
fi
echo ""
echo "🗑️  Self-destructing setup script..."
echo "🗑️  Backing up to .fountainpub.d/setup-fountainpub.sh.bak"
mkdir -p .fountainpub.d
cp "$0" .fountainpub.d/setup-fountainpub.sh.bak
rm -f "$0"
echo "✨ Setup complete! Script removed."
