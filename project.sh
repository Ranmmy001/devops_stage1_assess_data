#!/bin/bash


read -p "Enter your Firstname: " Firstname

read -p "Enter your Lastname: " Lastname

read -p "Enter Email address: " Email_address

read -p "Enter your password: " Password

user=("$Firstname" "$Lastname" "$Email_address" "$Password")

echo "${user[@]}" 

echo "Welcome, ${user[@]} !"
