
#!/bin/bash

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

read -p "Enter username to update password: " username
update_user_password "$username"
