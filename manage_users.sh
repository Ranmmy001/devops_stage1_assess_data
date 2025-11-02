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
