#!/bin/bash

# Repository-tracked Fountain Auto-Sync Daemon
# Monitors GitHub Actions and automatically syncs generated files
# Works the same everywhere with no local configuration needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PIDFILE="$SCRIPT_DIR/.fountain-auto-sync.pid"
LOGFILE="$SCRIPT_DIR/.fountain-auto-sync.log"
CHECK_INTERVAL=30   # Check every 45 seconds
DAEMON_LIFETIME=180 # Auto-suicide after 3 minutes (180 seconds)

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >>"$LOGFILE"
}

# Function to check if daemon is already running
is_running() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            return 0 # Running
        else
            rm -f "$PIDFILE" # Stale PID file
            return 1         # Not running
        fi
    fi
    return 1 # Not running
}

# Function to check GitHub Actions status using gh cli
check_actions_status() {
    if command -v gh >/dev/null 2>&1; then
        # Check if there are any running fountain-export workflows
        local running_workflows=$(gh run list --workflow="fountain-export.yml" --status=in_progress --json status --jq length 2>/dev/null || echo "0")
        echo "$running_workflows"
    else
        echo "0"
    fi
}

# Function to sync if actions completed
sync_if_needed() {
    cd "$REPO_DIR" || return 1

    # Fetch latest to check for new commits
    if git fetch origin >/dev/null 2>&1; then
        local current_commit=$(git rev-parse HEAD)
        local remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "")

        if [ -n "$remote_commit" ] && [ "$current_commit" != "$remote_commit" ]; then
            log_message "New commits detected, checking for generated files..."

            # Check if the new commits contain PDF/HTML files (generated files)
            local generated_files=$(git diff --name-only HEAD origin/main 2>/dev/null | grep -E '\.(pdf|html)$' | wc -l || echo "0")

            if [ "$generated_files" -gt 0 ]; then
                log_message "Found $generated_files generated files, syncing..."

                # Stash any local changes (like log files) before pulling
                local stash_result=""
                if ! git diff-index --quiet HEAD --; then
                    log_message "Working tree is dirty, stashing local changes..."
                    stash_result=$(git stash push -m "Auto-sync: temporary stash $(date)" 2>/dev/null || echo "failed")
                fi

                # Try to pull the changes
                if git pull origin main >/dev/null 2>&1 || git pull origin master >/dev/null 2>&1; then
                    log_message "✅ Successfully synced generated files"

                    # Restore stashed changes if we stashed them
                    if [ "$stash_needed" = true ]; then
                        if git stash pop >/dev/null 2>&1; then
                            log_message "✅ Restored local changes"
                        else
                            log_message "⚠️  Note: Could not restore stashed changes"
                        fi
                    fi

                    # Show what was updated
                    git diff --name-only HEAD~1 HEAD | grep -E '\.(pdf|html)$' | while read -r file; do
                        log_message "  📄 Updated: $file"
                    done

                    # Restore stashed changes if we stashed them
                    if [ -n "$stash_result" ] && [ "$stash_result" != "failed" ]; then
                        git stash pop >/dev/null 2>&1 || log_message "Note: Could not restore stashed changes"
                    fi

                    # Return special code to indicate successful sync
                    return 2
                else
                    log_message "❌ Failed to pull changes"

                    # Try to restore stashed changes even if pull failed
                    if [ -n "$stash_result" ] && [ "$stash_result" != "failed" ]; then
                        git stash pop >/dev/null 2>&1 || log_message "Note: Could not restore stashed changes"
                    fi

                    return 1
                fi
            fi
        fi
    fi

    return 0
}

# Function to start the daemon
start_daemon() {
    if is_running; then
        echo "Fountain auto-sync daemon is already running (PID: $(cat $PIDFILE))"
        return 1
    fi

    echo "Starting fountain auto-sync daemon (3-minute timer)..."
    log_message "🚀 Starting fountain auto-sync daemon (3-minute auto-stop)"

    # Check if gh cli is available
    if command -v gh >/dev/null 2>&1; then
        log_message "✅ GitHub CLI detected - will monitor Actions in real-time"
    else
        log_message "⚠️  GitHub CLI not found - using polling mode only"
    fi

    # Start daemon in background
    (
        cd "$REPO_DIR" || exit 1

        local start_time=$(date +%s)
        local last_action_check=0

        log_message "🔄 Daemon started with PID $$, monitoring repository for 3 minutes"

        while true; do
            current_time=$(date +%s)

            # Check if daemon should auto-suicide after 3 minutes
            local elapsed=$((current_time - start_time))
            if [ $elapsed -ge $DAEMON_LIFETIME ]; then
                log_message "⏰ 3-minute timer expired - daemon auto-stopping"
                break
            fi

            # Check GitHub Actions status every 30 seconds
            if [ $((current_time - last_action_check)) -ge 30 ]; then
                running_actions=$(check_actions_status)
                if [ "$running_actions" -gt 0 ]; then
                    log_message "🔄 $running_actions GitHub Actions running..."
                fi
                last_action_check=$current_time
            fi

            # Always check for new commits and sync if needed
            sync_result=$(
                sync_if_needed
                echo $?
            )
            if [ "$sync_result" = "2" ]; then
                log_message "✅ Files successfully synced - daemon mission accomplished, exiting early"
                break
            elif [ "$sync_result" = "0" ]; then
                # No sync needed, continue monitoring
                : # Do nothing, continue loop
            else
                # Sync failed or other issue
                log_message "⚠️  Sync check completed with issues"
            fi

            sleep $CHECK_INTERVAL
        done

        # Clean up when exiting
        rm -f "$PIDFILE"
        log_message "✅ Daemon auto-stopped after 3 minutes"
    ) &

    local daemon_pid=$!
    echo "$daemon_pid" >"$PIDFILE"
    echo "Fountain auto-sync daemon started with PID $daemon_pid (3-minute timer)"
    log_message "✅ Daemon ready - monitoring for 3 minutes"
}

# Function to stop the daemon
stop_daemon() {
    if ! is_running; then
        echo "Fountain auto-sync daemon is not running"
        return 1
    fi

    local pid=$(cat "$PIDFILE")
    echo "Stopping fountain auto-sync daemon (PID: $pid)..."
    log_message "⏹️  Stopping fountain auto-sync daemon"

    if kill "$pid" 2>/dev/null; then
        # Wait for process to stop
        local count=0
        while ps -p "$pid" >/dev/null 2>&1 && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done

        if ps -p "$pid" >/dev/null 2>&1; then
            # Force kill if still running
            kill -9 "$pid" 2>/dev/null
            log_message "🔨 Force killed daemon process"
        fi

        rm -f "$PIDFILE"
        echo "Fountain auto-sync daemon stopped"
        log_message "✅ Daemon stopped successfully"
    else
        echo "Error: Could not stop daemon"
        rm -f "$PIDFILE" # Clean up stale PID file
        return 1
    fi
}

# Function to show daemon status
status_daemon() {
    if is_running; then
        local pid=$(cat "$PIDFILE")
        echo "🟢 Fountain auto-sync daemon is running (PID: $pid)"

        # Show GitHub CLI status
        if command -v gh >/dev/null 2>&1; then
            echo "✅ GitHub CLI available for real-time monitoring"

            # Show current action status
            local running=$(check_actions_status)
            if [ "$running" -gt 0 ]; then
                echo "🔄 $running GitHub Actions currently running"
            else
                echo "✅ No GitHub Actions currently running"
            fi
        else
            echo "⚠️  GitHub CLI not available - using polling mode only"
        fi

        # Show recent log entries
        if [ -f "$LOGFILE" ]; then
            echo ""
            echo "📋 Recent activity (last 5 entries):"
            tail -5 "$LOGFILE" | sed 's/^/  /'
        fi
    else
        echo "🔴 Fountain auto-sync daemon is not running"
        echo ""
        echo "💡 Start with: ./.fountainpub.d/fountain-auto-sync-daemon.sh start"
        echo "💡 Or use: ./.fountainpub.d/start-auto-sync.sh"
    fi
}

# Function to restart the daemon
restart_daemon() {
    echo "🔄 Restarting fountain auto-sync daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

# Main script logic
case "${1:-start}" in
start)
    start_daemon
    ;;
stop)
    stop_daemon
    ;;
restart)
    restart_daemon
    ;;
status)
    status_daemon
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status}"
    echo ""
    echo "🔄 Fountain Auto-Sync Daemon Commands:"
    echo "  start   - Start the auto-sync daemon"
    echo "  stop    - Stop the auto-sync daemon"
    echo "  restart - Restart the auto-sync daemon"
    echo "  status  - Show daemon status and recent activity"
    echo ""
    echo "💡 Quick start: ./.fountainpub.d/start-auto-sync.sh"
    exit 1
    ;;
esac
