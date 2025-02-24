# SysSentry

SysSentry is a robust system maintenance shell script designed to streamline the management of system resources and operations. This script includes features such as package updates, backups, temporary file cleanup, and orphan package removal, making it an essential tool for system administrators.

## Features

- **System Updates**: Synchronizes package databases and checks for package updates.
- **Auto-Updates**: Optionally auto-updates non-critical packages.
- **Backup Management**: Backs up specified directories using `rsync`.
- **Temporary File Cleanup**: Cleans temporary files older than 1 day from designated directories.
- **Orphan Package Removal**: Removes orphan packages to maintain dependency hygiene.
- **Old Backup Cleanup**: Cleans backup directories older than 5 days.
- **Comprehensive Logging**: Logs all activities with color-coded messages and structured section headers.
- **Configuration File Management**: Creates a default configuration file if not found.

## Requirements

- Arch-based Linux distribution
- Shell (Bash)
- `rsync` package

## Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/YashSaini99/SysSentry.git
    cd SysSentry
    ```

## Usage

1. Make the script executable:
    ```sh
    chmod +x system_maintenance.sh
    ```

2. Run the script:
    ```sh
    sudo ./system_maintenance.sh
    ```

## Configuration

The script uses a configuration file located at `/etc/system_maintenance.conf`. If the configuration file does not exist, the script will create a default one. You can customize the following settings in the configuration file:

- **LOGFILE**: Path to the log file (ensure the directory is writable by root).
- **BACKUP_BASE**: Root backup directory.
- **BACKUP_DIRS**: Array of directories to back up.
- **TEMP_DIRS**: Array of temporary directories to clean (files older than 1 day will be removed).
- **AUTO_UPDATE**: Set to "yes" to automatically update non-critical packages.

Example configuration file:
```sh
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
```

## Automating with systemd

To automate the script using `systemd`, create a service unit file and a timer unit file.

1. Create the service unit file `/etc/systemd/system/system_maintenance.service`:
    ```ini
    [Unit]
    Description=System Maintenance Service
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=/path/to/system_maintenance.sh

    [Install]
    WantedBy=multi-user.target
    ```

2. Create the timer unit file `/etc/systemd/system/system_maintenance.timer`:
    ```ini
    [Unit]
    Description=Run System Maintenance daily

    [Timer]
    OnCalendar=daily
    Persistent=true

    [Install]
    WantedBy=timers.target
    ```

3. Enable and start the timer:
    ```sh
    sudo systemctl enable system_maintenance.timer
    sudo systemctl start system_maintenance.timer
    ```

## Automating with Anacron

To automate the script using `Anacron`, create a job in the Anacron job directory.

1. Add the job to `/etc/anacrontab`:
    ```sh
    # /etc/anacrontab: configuration file for Anacron

    # Fields:
    # period  delay   job-identifier  command
    1        5       system_maintenance   /path/to/system_maintenance.sh
    ```

2. Ensure Anacron is installed and enabled:
    ```sh
    sudo pacman -S anacron
    sudo systemctl enable anacron.service
    sudo systemctl start anacron.service
    ```

