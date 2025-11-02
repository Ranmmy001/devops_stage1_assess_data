#!/bin/bash

# Read each line in the file users.csv
while IFS=',' read -r firstname lastname email password plan
do
    # skip empty lines
    [[ -z "$firstname" ]] && continue

    username="${firstname,,}${lastname,,}"  # lowercase combined name

    echo "Creating user: $username"
    echo "Email: $email"
    echo "Plan: $plan"

    # create user with home directory (-m) and comment (-c)
    sudo useradd -m -c "$firstname $lastname, $email" "$username"

    # set password
    echo "$username:$password" | sudo chpasswd

    # create group for plan if not exists
    sudo groupadd -f "$plan"

    # add user to that plan group
    sudo usermod -aG "$plan" "$username"

    echo "User $username created and added to group $plan."
    echo "---------------------------------------"
done < users.csv
#!/bin/bash

# Read each line in the file users.csv
while IFS=',' read -r firstname lastname email password plan
do
    echo "Creating user: $firstname $lastname"
    echo "Email: $email"
    echo "Password: $password"
    echo "Plan: $plan"
    echo "----------------------"
done < users.csv
