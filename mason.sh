#!/bin/bash

# First script to run on a new host to setup the connection to the server.

# Inputs:
# - $1: API Key

# --------------------------------- Processes -------------------------------- #
# 1. Create "bb_root" user
# 2. Create "/etc/sshtunnel" directory
# 3. Generate sshtunnel key pair
# 4. Read the host serial number
# 5. POST the host serial number and sshtunnel public key to the server using the API key
# 6. Recive back the bb_root public key and add to authorized_keys
# 7. Recive back assigned SSH tunnel port
# 8. Create the SSH tunnel

# Check if the user "bb_root" exsists, if not create it and set to root.
if ! id -u bb_root > /dev/null 2>&1; then
    useradd -m -s /bin/bash bb_root
    echo "bb_root:root" | chpasswd
fi

# Create "/etc/sshtunnel" directory
mkdir -p /etc/sshtunnel

# Generate sshtunnel key pair
ssh-keygen -qN "" -f /etc/sshtunnel/id_rsa

# Read the host serial number
host_serial=$(dmidecode -s system-serial-number)

# POST the host serial number and sshtunnel public key to the server using the API key
