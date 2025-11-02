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
