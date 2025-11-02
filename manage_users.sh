#!/bin/bash
# =========================================
# Manage Users — Create, Delete, Restore, Update, and Group assignment
# =========================================

# --- Function 1: Create user ---
create_user_account() {
    read -p "Enter username to create: " username
    if id "$username" &>/dev/null; then
        echo "⚠️  User '$username' already exists."
        return 1
    fi

    sudo useradd -m "$username" || {
        echo "❌ Failed to create user '$username'"
        return 1
    }

    read -s -p "Enter password for $username: " password
    echo
    echo "$username:$password" | sudo chpasswd
    echo "✅ User '$username' created successfully."
}



# --- Function 2: Delete user (with backup) ---
delete_user_account() {
    local username="$1"

    if [[ -z "$username" ]]; then
        echo "❌ Please provide a username."
        return 1
    fi
    if ! id "$username" &>/dev/null; then
        echo "⚠️  User '$username' does not exist."
        return 1
    fi

    read -p "Are you sure you want to delete '$username'? (y/n): " confirm
    [[ "$confirm" != [yY] ]] && { echo "❎ Cancelled."; return 0; }

    local backup_dir="/var/backups/users"
    sudo mkdir -p "$backup_dir"
    local home_dir="/home/$username"
    if [[ -d "$home_dir" ]]; then
        local archive="$backup_dir/${username}_home_$(date +%F).tar.gz"
        echo "📦 Archiving $home_dir ..."
        sudo tar -czf "$archive" "$home_dir"
        echo "✅ Backup stored at $archive"
    fi

    sudo userdel "$username"
    echo "✅ User '$username' deleted."
}



# --- Function 3: Restore user home backup ---
restore_user_account() {
    local username="$1"
    [[ -z "$username" ]] && { echo "❌ Provide username."; return 1; }

    local backup_dir="/var/backups/users"
    local latest=$(ls -t "$backup_dir"/${username}_home_*.tar.gz 2>/dev/null | head -n 1)
    [[ -z "$latest" ]] && { echo "⚠️  No backup found."; return 1; }

    read -p "Restore $latest for '$username'? (y/n): " c
    [[ "$c" != [yY] ]] && { echo "❎ Cancelled."; return 0; }

    sudo mkdir -p /home/$username
    sudo tar -xzf "$latest" -C /
    sudo chown -R "$username":"$username" /home/$username
    echo "♻️  Restored /home/$username"
}



# --- Function 4: Update password ---
update_user_password() {
    local username="$1"
    [[ -z "$username" ]] && { echo "Usage: update_user_password <username>"; return 1; }

    if ! id "$username" &>/dev/null; then
        echo "⚠️  User '$username' does not exist."
        return 1
    fi

    read -s -p "Enter new password for $username: " p1
    echo
    read -s -p "Confirm new password: " p2
    echo

    [[ "$p1" != "$p2" ]] && { echo "❌ Passwords do not match."; return 1; }

    echo "$username:$p1" | sudo chpasswd && echo "✅ Password updated for $username."
}



# --- Function 5: Add user to groups ---
add_user_to_group() {
    local username="$1"; shift
    local groups=("$@")

    [[ -z "$username" ]] && { echo "Usage: add_user_to_group <user> <group1> [group2]"; return 1; }
    if ! id "$username" &>/dev/null; then
        echo "⚠️  User '$username' does not exist."
        return 2
    fi
    [[ ${#groups[@]} -eq 0 ]] && { echo "⚠️  No groups provided."; return 3; }

    for g in "${groups[@]}"; do
        if ! getent group "$g" >/dev/null; then
            echo "🆕 Creating group '$g'..."
            sudo groupadd "$g"
        fi
        sudo usermod -aG "$g" "$username"
        echo "✅ Added '$username' to '$g'"
    done
}



# ==================================================
# Function 6: remove_user_from_group
# ==================================================
remove_user_from_group() {
    local username="$1"
    shift
    local groups=("$@")

    # --- Input validation ---
    if [[ -z "$username" ]]; then
        echo "❌ Usage: remove_user_from_group <username> <group1> [group2] ..."
        return 1
    fi

    if ! id "$username" &>/dev/null; then
        echo "⚠️  User '$username' does not exist."
        return 2
    fi

    if [[ ${#groups[@]} -eq 0 ]]; then
        echo "⚠️  No group names provided."
        return 3
    fi

    local primary_group
    primary_group=$(id -gn "$username")

    # --- Loop through groups ---
    for group in "${groups[@]}"; do
        if [[ "$group" == "$primary_group" ]]; then
            echo "⚠️  Cannot remove '$username' from their primary group '$group'."
            continue
        fi

        # Check if group exists
        if ! getent group "$group" >/dev/null; then
            echo "⚠️  Group '$group' does not exist."
            continue
        fi

        # Check if user belongs to the group
        if id -nG "$username" | grep -qw "$group"; then
            echo "Removing '$username' from '$group'..."
            sudo gpasswd -d "$username" "$group" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                echo "✅ Successfully removed '$username' from '$group'"
            else
                echo "❌ Failed to remove '$username' from '$group'"
            fi
        else
            echo "ℹ️  User '$username' is not a member of '$group'."
        fi
    done

    echo "🎯 Group removal process completed for $username."
}

# =========================================
# MENU SECTION
# =========================================
echo "--------------------------------------"
echo " User Management Menu"
echo "--------------------------------------"
echo "1. Create user"
echo "2. Delete user"
echo "3. Restore user"
echo "4. Update user password"
echo "5. Add user to group"
echo "6. Remove_user_from_group"
echo "--------------------------------------"
read -p "Enter choice [1-6]: " choice

case "$choice" in
  1)
    read -p "Enter username to create: " u
    create_user_account "$u"
    ;;
  2)
    read -p "Enter username to delete: " u
    delete_user_account "$u"
    ;;
  3)
    read -p "Enter username to restore: " u
    restore_user_account "$u"
    ;;
  4)
    read -p "Enter username to update password: " u
    update_user_password "$u"
    ;;
  5)
    read -p "Enter username: " u
    read -p "Enter groups (space-separated): " -a g
    add_user_to_group "$u" "${g[@]}"
    ;;
  6)
    read -p "Enter username: " user
        read -p "Enter groups to remove (separated by spaces): " -a group_list
        remove_user_from_group "$user" "${group_list[@]}"
        ;;
  *)
    echo "Invalid choice."
    ;;
esac
