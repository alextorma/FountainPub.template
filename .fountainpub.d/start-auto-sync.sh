#!/bin/bash

# Repository-tracked auto-sync starter
# This script automatically starts the sync daemon and sets up repository-based automation
# Works the same everywhere with no local configuration needed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

echo "🚀 Starting fountain auto-sync system..."

# Apply repository git configuration if not already applied
if ! git config --local --get include.path >/dev/null 2>&1; then
    echo "📋 Applying repository Git configuration..."
    git config --local include.path ../.fountainpub.d/.gitconfig-local
fi

# Start the sync daemon
echo "🔄 Starting 3-minute sync daemon..."
./.fountainpub.d/fountain-auto-sync-daemon.sh start

echo "✅ Auto-sync system started!"
echo ""
echo "💡 Enhanced Git workflow:"
echo "   git push     # Pushes and starts 3-minute auto-sync daemon"
echo "   git pull     # Normal pull (daemon auto-stops after 3 min)"
echo ""
echo "🔍 Check daemon status: ./.fountainpub.d/fountain-auto-sync-daemon.sh status"
echo "⏹️  Stop daemon: ./.fountainpub.d/fountain-auto-sync-daemon.sh stop"
