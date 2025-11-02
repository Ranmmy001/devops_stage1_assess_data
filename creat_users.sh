#!/bin/bash
# create_users.sh — Create user accounts from accounts.txt
# Author: Olatunde
# Description: Reads names from accounts.txt, creates Linux users,
# generates random passwords, and sets up their home directories.

# Input file
input_file="accounts.txt"

# Check if file exists
if [[ ! -f "$input_file" ]]; then
    echo "❌ Error: '$input_file' not found!"
    exit 1
fi

echo "🔹 Starting user creation process..."
echo "------------------------------------"

# Loop through each line of the file
while read -r firstname lastname
do
    # skip empty lines
    [[ -z "$firstname" || -z "$lastname" ]] && continue

    username="${firstname,,}${lastname,,}"  # make lowercase username

    # check if user already exists
    if id "$username" &>/dev/null; then
        echo "⚠️  User '$username' already exists — skipping."
        continue
    fi

    # generate a secure random password (12 characters)
    password=$(openssl rand -base64 12)

    # create user with home directory (-m)
    if sudo useradd -m -c "$firstname $lastname" "$username"; then
        echo "$username:$password" | sudo chpasswd
        sudo chmod 700 /home/"$username"

        echo "✅ User '$username' created successfully."
        echo "   → Password: $password"
        echo "------------------------------------"

        # log to a file
        echo "$username,$password" >> created_users.log
    else
        echo "❌ Failed to create user '$username'."
    fi

done < "$input_file"

echo "🎉 All done! User passwords saved in 'created_users.log'."
