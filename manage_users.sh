#!/bin/bash
# manage_users.sh — Manage and delete user accounts safely

delete_user_account() {
    local username=$1

    # Check if username was provided
    if [[ -z "$username" ]]; then
        echo "❌ Please provide a username."
        return 1
    fi

    # Check if user exists
    if ! id "$username" &>/dev/null; then
        echo "⚠️  User '$username' does not exist."
        return 1
    fi

    # Ask for confirmation
    read -p "Are you sure you want to delete user '$username'? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "❎ Deletion cancelled."
        return 0
    fi

    # Create backup directory if not exists
    backup_dir="/var/backups/users"
    sudo mkdir -p "$backup_dir"

    # Archive the user's home directory
    home_dir="/home/$username"
    if [[ -d "$home_dir" ]]; then
        archive_file="$backup_dir/${username}_home_$(date +%F).tar.gz"
        echo "📦 Archiving $home_dir to $archive_file ..."
        sudo tar -czf "$archive_file" "$home_dir"
        echo "✅ Archive complete."
    else
        echo "⚠️  No home directory found for $username."
    fi

    # Delete the user (but keep home dir just in case)
    echo "🗑️  Removing user '$username' ..."
    sudo userdel "$username"

    echo "✅ User '$username' deleted safely. Archive stored at $archive_file."
}

# If you want to run it directly:
read -p "Enter the username to delete: " user_to_delete
delete_user_account "$user_to_delete"








restore_user_account() {
    local username=$1

    # Check if username was provided
    if [[ -z "$username" ]]; then
        echo "❌ Please provide a username to restore."
        return 1
    fi

    # Define the backup directory
    local backup_dir="/var/backups/users"
    local latest_backup=$(ls -t "$backup_dir"/${username}_home_*.tar.gz 2>/dev/null | head -n 1)

    # Check if backup exists
    if [[ -z "$latest_backup" ]]; then
        echo "⚠️  No backup archive found for '$username'."
        return 1
    fi

    echo "📦 Found backup: $latest_backup"

    # Ask for confirmation
    read -p "Are you sure you want to restore this backup for '$username'? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "❎ Restore cancelled."
        return 0
    fi

    # Create home directory if missing
    if [[ ! -d /home/$username ]]; then
        sudo mkdir -p /home/$username
        sudo chown "$username":"$username" /home/$username
    fi

    echo "♻️  Restoring home directory for $username ..."
    sudo tar -xzf "$latest_backup" -C /

    echo "✅ Restoration complete! Home directory restored to /home/$username"
}


echo "Select an option:"
echo "1. Delete a user"
echo "2. Restore a user"
read -p "Enter choice [1/2]: " choice

case $choice in
  1)
    read -p "Enter the username to delete: " user_to_delete
    delete_user_account "$user_to_delete"
    ;;
  2)
    read -p "Enter the username to restore: " user_to_restore
    restore_user_account "$user_to_restore"
    ;;
  *)
    echo "Invalid choice."
    ;;
esac







#!/usr/bin/env bash

LOGFILE="/var/log/user_password_changes.log"

# Ensure the log file exists and has safe permissions
init_password_log() {
    if [[ ! -f "$LOGFILE" ]]; then
        sudo touch "$LOGFILE"
        sudo chown root:root "$LOGFILE"
        sudo chmod 600 "$LOGFILE"
    fi
}

# Password complexity check:
# - at least 12 chars
# - at least one lowercase
# - at least one uppercase
# - at least one digit
# - at least one special char
validate_password() {
    local pass="$1"

    # length check
    if (( ${#pass} < 12 )); then
        echo "Password must be at least 12 characters long."
        return 1
    fi
    # lowercase
    if ! [[ $pass =~ [a-z] ]]; then
        echo "Password must include at least one lowercase letter."
        return 2
    fi
    # uppercase
    if ! [[ $pass =~ [A-Z] ]]; then
        echo "Password must include at least one uppercase letter."
        return 3
    fi
    # digit
    if ! [[ $pass =~ [0-9] ]]; then
        echo "Password must include at least one digit."
        return 4
    fi
    # special char
    if ! [[ $pass =~ [\!\@\#\$\%\^\&\*\(\)\-\_\=\+\[\]\{\}\:\;\"\'\<\>\,\.\?\/\\\|] ]]; then
        echo "Password must include at least one special character (e.g. !@#\$%)."
        return 5
    fi

    return 0
}

# Main function: update_user_password username [--force-change]
# Usage: sudo update_user_password alice --force-change
update_user_password() {
    local username="$1"
    local force_change=0

    [[ -z "$username" ]] && { echo "Usage: update_user_password <username> [--force-change]"; return 2; }

    if [[ "$2" == "--force-change" ]]; then
        force_change=1
    fi

    # Ensure logfile exists and permissions are correct (only root can read/write)
    init_password_log

    # Check user exists
    if ! id "$username" &>/dev/null; then
        echo "User '$username' does not exist."
        printf '%s\n' "$(date --iso-8601=seconds) | $USER | $username | FAILED | user-not-found" | sudo tee -a "$LOGFILE" >/dev/null
        return 3
    fi

    # Prompt for new password (hidden)
    read -s -p "Enter new password for $username: " passwd1
    echo
    read -s -p "Confirm new password: " passwd2
    echo

    if [[ "$passwd1" != "$passwd2" ]]; then
        echo "Passwords do not match. Aborting."
        printf '%s\n' "$(date --iso-8601=seconds) | $USER | $username | FAILED | mismatch" | sudo tee -a "$LOGFILE" >/dev/null
        return 4
    fi

    # Validate password complexity
    local validation_output
    if ! validation_output="$(validate_password "$passwd1" 2>&1)"; then
        echo "Password validation failed: $validation_output"
        printf '%s\n' "$(date --iso-8601=seconds) | $USER | $username | FAILED | complexity-check" | sudo tee -a "$LOGFILE" >/dev/null
        return 5
    fi

    # Set the password securely (use chpasswd, pipe password via stdin)
    if printf "%s:%s\n" "$username" "$passwd1" | sudo chpasswd; then
        # Optionally force password change at next login
        if (( force_change == 1 )); then
            sudo chage -d 0 "$username"
            change_note="password-set;force-change"
        else
            change_note="password-set"
        fi

        echo "Password updated for $username."

        # Log success (do NOT log password)
        printf '%s\n' "$(date --iso-8601=seconds) | $USER | $username | SUCCESS | $change_note" | sudo tee -a "$LOGFILE" >/dev/null

        # Drop the password variables from memory
        passwd1=""
        passwd2=""
        unset passwd1 passwd2

        return 0
    else
        echo "Failed to update password for $username (chpasswd error)."
        printf '%s\n' "$(date --iso-8601=seconds) | $USER | $username | FAILED | chpasswd-error" | sudo tee -a "$LOGFILE" >/dev/null
        return 6
    fi
}







update_user_password() {
    local username="$1"

    if [[ -z "$username" ]]; then
        echo "Usage: update_user_password <username>"
        return 1
    fi

    # Check if the user exists
    if ! id "$username" &>/dev/null; then
        echo "User '$username' does not exist."
        return 2
    fi

    # Ask for password input
    read -s -p "Enter new password for $username: " passwd1
    echo
    read -s -p "Confirm new password: " passwd2
    echo

    if [[ "$passwd1" != "$passwd2" ]]; then
        echo "Passwords do not match!"
        return 3
    fi

    # Change the password
    echo "$username:$passwd1" | sudo chpasswd

    if [[ $? -eq 0 ]]; then
        echo "Password updated for $username."
    else
        echo "Failed to update password for $username."
    fi
}





echo "Select an option:"
echo "1. Create user"
echo "2. Delete user"
echo "3. Update user password"
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        read -p "Enter username to create: " newuser
        create_user_account "$newuser"
        ;;
    2)
        read -p "Enter username to delete: " deluser
        delete_user_account "$deluser"
        ;;
    3)
        read -p "Enter username to change: " chuser
        update_user_password "$chuser"
        ;;
    *)
        echo "Invalid choice!"
        ;;
esac







