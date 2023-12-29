#!/bin/bash

# Check if terraform.tfstate exists and remove it if it does
if [ -f terraform.tfstate ]; then
    rm terraform.tfstate
    echo "terraform.tfstate removed"
else
    echo "terraform.tfstate does not exist"
fi

# Check if inventory.ini exists and remove it if it does
if [ -f inventory.ini ]; then
    rm inventory.ini
    echo "inventory.ini removed"
else
    echo "inventory.ini does not exist"
fi

# Check if connect_to_ec2.sh exists and remove it if it does
if [ -f connect_to_ec2.sh ]; then
    rm connect_to_ec2.sh
    echo "connect_to_ec2.sh removed"
else
    echo "connect_to_ec2.sh does not exist"
fi
