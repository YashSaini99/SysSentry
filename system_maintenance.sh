#!/bin/bash
# system_maintenance.sh
# A system maintenance script with auto-creation of configuration file,
# This script:
#   - Synchronizes package databases and checks for package updates (similar to pacman -Syu)
#   - Optionally auto-updates non-critical packages
#   - Backs up specified directories using rsync
#   - Cleans temporary files older than 1 day from designated directories
#   - Removes orphan packages (dependency management)
#   - Cleans backup directories older than 5 days
#   - Logs all activities with color-coded messages and structured section headers
#
# If the configuration file is not found, a default one is created automatically.

# Use strict mode for unset variables and pipeline errors.
set -u
set -o pipefail

CONFIG_FILE="/etc/system_maintenance.conf"

# Trap to catch unexpected errors and log exit status.
on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "ERROR: Script exited unexpectedly with exit code $exit_code"
    else
        log "Script execution completed."
    fi
}
trap on_exit EXIT

# Function to print section headers with borders.
section_header() {
    local title="$1"
    local border="###############################################################"
    echo -e "\n\033[36m$border\033[0m"
    echo -e "\033[36m# $(printf "%-57s" "$title") #\033[0m"
    echo -e "\033[36m$border\033[0m\n"
    echo "$title" >> "$LOGFILE"
}

# Function for logging with color-coded messages.
log() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # ANSI color codes.
    local color_reset="\033[0m"
    local color_info="\033[32m"    # Green for normal messages.
    local color_warn="\033[33m"    # Yellow for warnings.
    local color_error="\033[31m"   # Red for errors.
    local color_header="\033[36m"  # Cyan for headers.

    local color="$color_info"
    if [[ "$message" == ERROR:* ]]; then
        color="$color_error"
    elif [[ "$message" == WARNING:* ]]; then
        color="$color_warn"
    elif [[ "$message" == "===================="* || "$message" == "System Maintenance"* ]]; then
        color="$color_header"
    fi

    echo -e "$timestamp - ${color}${message}${color_reset}"
    echo "$timestamp - $message" >> "$LOGFILE"
}

#############################
# 0. Configuration File Setup
#############################
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat << 'EOF' > "$CONFIG_FILE"
#!/bin/bash
# /etc/system_maintenance.conf
# Default configuration for System Maintenance Script

# Log file path (ensure that the directory is writable by root)
LOGFILE="/var/log/system_maintenance.log"

# Backup configuration:
# BACKUP_BASE is the root backup directory.
BACKUP_BASE="/backup"
# BACKUP_DIRS is an array of directories to back up.
declare -a BACKUP_DIRS=(
    "/etc"
    "/var/www"
)

# Temporary directories to clean (files older than 1 day will be removed)
declare -a TEMP_DIRS=(
    "/tmp"
    "/var/tmp"
)

# Update configuration:
# Set AUTO_UPDATE to "yes" to automatically update non-critical packages.
AUTO_UPDATE="no"
EOF

    chmod 600 "$CONFIG_FILE"
    echo "Default configuration file created at $CONFIG_FILE"
fi

# Load configuration.
source "$CONFIG_FILE"

# Ensure the script is run as root.
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

#############################
# Main Routine
#############################
section_header "System Maintenance Routine Started"

#############################
# 1. Check for System Updates
#############################
section_header "1. Checking System Updates"
log "Synchronizing package databases..."
sync_output=$(pacman -Sy 2>&1)
if [[ $? -eq 0 ]]; then
    log "Package databases synchronized successfully."
else
    log "ERROR: Failed to synchronize package databases. Output: $sync_output"
fi

log "Checking for package updates..."
updates_output=$(pacman -Qu 2>&1)
if [[ -n "$updates_output" ]]; then
    log "Updates available:"
    log "$updates_output"
    if [[ "$AUTO_UPDATE" == "yes" ]]; then
        log "Auto-update enabled. Running pacman -Syu..."
        update_output=$(pacman -Syu --noconfirm 2>&1)
        if [[ $? -eq 0 ]]; then
            log "System updated successfully."
        else
            log "ERROR: System update encountered errors. Output: $update_output"
        fi
    fi
else
    log "No updates available. System is up-to-date."
fi

#############################
# 2. Backup Routine
#############################
section_header "2. Backup Routine"
# Ensure backup base directory exists; if not, create it.
if [[ ! -d "$BACKUP_BASE" ]]; then
    if mkdir -p "$BACKUP_BASE"; then
        log "Backup base directory $BACKUP_BASE created successfully."
    else
        log "ERROR: Failed to create backup base directory $BACKUP_BASE."
        exit 1
    fi
fi

log "Starting backup routines..."
for SRC_DIR in "${BACKUP_DIRS[@]}"; do
    if [[ -d "$SRC_DIR" ]]; then
        DIR_NAME=$(basename "$SRC_DIR")
        TARGET_DIR="${BACKUP_BASE}/$(date +'%Y%m%d')/${DIR_NAME}_backup"
        if mkdir -p "$TARGET_DIR"; then
            log "Backing up ${SRC_DIR} to ${TARGET_DIR}"
            rsync_output=$(rsync -a --delete "$SRC_DIR/" "$TARGET_DIR/" 2>&1)
            if [[ $? -eq 0 ]]; then
                log "Backup of ${SRC_DIR} completed successfully."
            else
                log "ERROR: Backup of ${SRC_DIR} encountered errors. Rsync output: $rsync_output"
            fi
        else
            log "ERROR: Failed to create backup directory ${TARGET_DIR}."
        fi
    else
        log "WARNING: Backup source directory ${SRC_DIR} does not exist. Skipping."
    fi
done

#############################
# 2a. Cleanup Old Backups
#############################
section_header "2a. Cleaning Up Old Backups"
cleanup_output=$(find "$BACKUP_BASE" -maxdepth 1 -type d -mtime +5 -exec rm -rf {} \; 2>&1)
if [[ $? -eq 0 ]]; then
    log "Old backups cleaned successfully."
else
    log "ERROR: Cleanup of old backups encountered errors. Output: $cleanup_output"
fi

#############################
# 3. Clean Temporary Files
#############################
section_header "3. Cleaning Temporary Files"
for TEMP_DIR in "${TEMP_DIRS[@]}"; do
    if [[ -d "$TEMP_DIR" ]]; then
        log "Cleaning files in ${TEMP_DIR} older than 1 day."
        temp_cleanup_output=$(find "$TEMP_DIR" -mindepth 1 -mtime +1 -exec rm -rf {} \; 2>&1)
        if [[ $? -eq 0 ]]; then
            log "Temporary files in ${TEMP_DIR} cleaned successfully."
        else
            log "ERROR: Issues encountered while cleaning ${TEMP_DIR}. Output: $temp_cleanup_output"
        fi
    else
        log "WARNING: Temporary directory ${TEMP_DIR} does not exist. Skipping."
    fi
done

#############################
# 4. Dependency Management
#############################
section_header "4. Dependency Management (Orphan Packages)"
if command -v pacman >/dev/null 2>&1; then
    orphans_output=$(pacman -Qtdq 2>&1)
    if [[ -n "$orphans_output" ]]; then
        log "Orphan packages found:"
        log "$orphans_output"
        removal_output=$(pacman -Rns ${orphans_output} --noconfirm 2>&1)
        if [[ $? -eq 0 ]]; then
            log "Orphan packages removed successfully."
        else
            log "ERROR: Failed to remove orphan packages. Output: $removal_output"
        fi
    else
        log "No orphan packages found."
    fi
else
    log "WARNING: 'pacman' command not found. Skipping dependency management."
fi

section_header "System Maintenance Routine Completed"
log "===================="
