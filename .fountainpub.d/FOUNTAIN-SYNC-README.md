# Fountain Auto-Generation Setup

This repository includes an **automatic generation system** that creates PDF and HTML files from Fountain scripts when you commit. The system uses **pre-commit hooks** as the primary method to generate files locally, with **GitHub Actions** as a fallback when `fountainpub` is not available locally.

## Quick Setup (One-Time)

After cloning this repository, run:

```sh
./setup-fountain-sync.sh
```

This script will:

- Install pre-commit hooks for local PDF/HTML generation
- Configure Git aliases to automatically manage sync
- Self-destruct after setup (backup saved to `.fountainpub.d/`)

**That's it!** No further configuration needed.

## How It Works

### Primary Method: Pre-Commit Hooks (Local Generation)

1. **Pre-Commit Hook** (`.fountainpub.d/hooks/pre-commit`)
   - Automatically detects modified `.fountain` files when you commit
   - Generates PDF and HTML files locally using `fountainpub` (if available)
   - Automatically includes generated files in your commit
   - **Instant generation** - no waiting for cloud processing

### Fallback Method: GitHub Actions (Cloud Generation)

1. **GitHub Actions Workflow** (`.github/workflows/fountain-export.yml`)
   - Automatically converts `.fountain` files to PDF and HTML on every push
   - **Only runs when `fountainpub` is not available locally**
   - Commits and pushes the generated files back to the repository

2. **Auto-Sync Daemon** (`fountain-auto-sync-daemon.sh`)
   - Monitors GitHub Actions status in real-time (if `gh` CLI is available)
   - Automatically pulls generated files when Actions complete
   - **Auto-stops after 3 minutes** to prevent resource waste
   - Logs all activity for debugging

3. **Repository Git Configuration** (`.gitconfig-local`)
   - Overrides `git push` to automatically start sync daemon after push
   - Preserves original `git push` as `git push_original`
   - Applied automatically during one-time setup

## Usage

### Normal Workflow (Pre-Commit Hook)

```sh
# Standard git workflow - files are generated automatically
git add my-screenplay.fountain
git commit -m "Update screenplay"  # ← PDF/HTML files generated and included automatically!
git push    # Optional: push with generated files
```

**What happens during `git commit`:**

1. Pre-commit hook detects modified `.fountain` files
2. Generates fresh PDF and HTML files using `fountainpub`
3. Automatically stages the generated files for inclusion in the commit
4. **All files are committed together** - no additional steps needed!

### Fallback Workflow (GitHub Actions)

If `fountainpub` is not available locally, the system falls back to GitHub Actions:

```sh
git add my-screenplay.fountain
git commit -m "Update screenplay"
git push    # ← Starts GitHub Actions + auto-sync daemon
```

**What happens during `git push` (fallback mode):**

1. Code is pushed to GitHub normally
2. GitHub Actions workflow generates PDF and HTML files (~30-60 seconds)
3. Auto-sync daemon starts locally (3-minute timer)
4. Daemon pulls generated files when Actions complete

## Manual Control (Fallback Mode)

```bash
# Check daemon status and recent activity
git sync-status

# Manually start 3-minute daemon
git sync-start

# Stop daemon early
git sync-stop

# Use original git push (bypasses auto-sync)
git push_original
```

## Features

- ✅ **Instant Generation**: Pre-commit hook generates files locally in seconds
- ✅ **VS Code Compatible**: Works seamlessly with VS Code's commit interface
- ✅ **Automatic Staging**: Generated files are automatically included in commits
- ✅ **Fallback Support**: GitHub Actions workflow when `fountainpub` unavailable
- ✅ **Minimal Setup**: One-time setup script that self-destructs
- ✅ **Smart Detection**: Only processes modified `.fountain` files
- ✅ **Repository-Tracked**: All sync logic is committed to Git

## Requirements

- **Primary**: `fountainpub` command-line tool for local generation
  - Install from: https://github.com/Theseus/fountainpub
- **Fallback**: `gh` CLI for GitHub Actions monitoring (optional)
  - Without `gh`: Uses polling mode (checks every 45 seconds)
  - With `gh`: Monitors Actions status in real-time

## File Structure

```
├── setup-fountain-sync.sh              # One-time setup script (self-destructs)
├── .fountainpub.d/
│   ├── hooks/
│   │   └── pre-commit                   # Pre-commit hook for local generation
│   ├── fountain-auto-sync-daemon.sh    # Auto-sync daemon (fallback mode)
│   ├── start-auto-sync.sh              # Daemon starter script
│   ├── .gitconfig-local                # Repository Git configuration
│   └── FOUNTAIN-SYNC-README.md         # This documentation
├── .github/workflows/
│   └── fountain-export.yml             # GitHub Actions workflow (fallback)
└── .fountain-auto-sync.log             # Sync activity log (created when running)
```

## Workflow Summary

### With `fountainpub` available (Primary):
1. Edit `.fountain` file
2. Commit changes → pre-commit hook generates PDF/HTML instantly
3. Push (optional) → all files already included in commit

### Without `fountainpub` (Fallback):
1. Edit `.fountain` file and commit normally
2. Push to GitHub → GitHub Actions generates files
3. Auto-sync daemon pulls generated files locally

**That's it!** The system automatically chooses the best method available.
