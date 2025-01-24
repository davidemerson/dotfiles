#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Function to check if a package is installed
ensure_installed() {
    if ! dpkg -l | grep -qw "$1"; then
        echo "Installing $1..."
        apt update && apt install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Install necessary packages
for package in curl micro git sudo; do
    ensure_installed "$package"
done

# Add users to sudoers
echo "Identified users on the system:"
users=$(awk -F: '{ print $1 }' /etc/passwd)
echo "$users"
echo "Enter the usernames to add to sudoers (separate by space):"
read -ra sudo_users
for user in "${sudo_users[@]}"; do
    if id -u "$user" >/dev/null 2>&1; then
        usermod -aG sudo "$user"
        echo "$user added to sudoers."
    else
        echo "User $user does not exist."
    fi
done

# Install salt-minion
ensure_installed salt-minion

# Set hostname
echo "Enter the desired hostname for this computer:"
read new_hostname
hostnamectl set-hostname "$new_hostname"
echo "Hostname set to $new_hostname."

# Disable gdm from starting by default
if systemctl is-enabled gdm >/dev/null 2>&1; then
    systemctl disable gdm
    echo "gdm disabled from starting by default."
else
    echo "gdm is already disabled."
fi

# Copy directories and apply Salt highstate
cp minion /etc/salt/minion
rm -rf /srv/salt/
mkdir -p /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate

# Update font cache
fc-cache
echo "Font cache updated."

# Set the time and configure daily ntpdate cron job
ntpdate 0.pool.ntp.org
if ! crontab -l | grep -q "ntpdate 0.pool.ntp.org"; then
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/sbin/ntpdate 0.pool.ntp.org") | crontab -
    echo "Daily ntpdate synchronization job added to cron."
else
    echo "Daily ntpdate synchronization job already exists."
fi

echo "Provisioning completed successfully."
