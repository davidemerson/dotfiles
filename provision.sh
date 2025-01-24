#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[1;33mThis script must be run as root.\033[0m"
   exit 1
fi

# Function to check if a package is installed
ensure_installed() {
    if ! dpkg -l | grep -qw "$1"; then
        echo -e "\033[1;33mInstalling $1...\033[0m"
        apt update && apt install -y "$1"
    else
        echo -e "\033[1;33m$1 is already installed.\033[0m"
    fi
}

# Install necessary packages
for package in curl micro git sudo; do
    ensure_installed "$package"
done

# Add users to sudoers
echo -e "\033[1;33mI see these users on the system:\033[0m"
users=$(awk -F: '{ print $1 }' /etc/passwd)
echo -e "\033[1;33m$users\033[0m"
echo -e "\033[1;33mEnter the usernames to add to sudoers, separated by space; (enter) to add none:\033[0m"
read -ra sudo_users
for user in "${sudo_users[@]}"; do
    if id -u "$user" >/dev/null 2>&1; then
        usermod -aG sudo "$user"
        echo -e "\033[1;33m$user added to sudoers.\033[0m"
    else
        echo -e "\033[1;33mUser $user does not exist.\033[0m"
    fi
done

# Install salt-minion
ensure_installed salt-minion

# Set hostname
current_hostname=$(hostname)
echo -e "\033[1;33mThe current hostname is: $current_hostname\033[0m"
echo -e "\033[1;33mPress (enter) to keep the current hostname, or specify a new hostname:\033[0m"
read new_hostname
if [ -z "$new_hostname" ]; then
    echo -e "\033[1;33mHostname unchanged.\033[0m"
else
    hostnamectl set-hostname "$new_hostname"
    echo -e "\033[1;33mHostname set to $new_hostname.\033[0m"
fi

# Disable gdm from starting by default
if systemctl is-enabled gdm >/dev/null 2>&1; then
    systemctl disable gdm
    echo -e "\033[1;33mgdm disabled from starting by default.\033[0m"
else
    echo -e "\033[1;33mgdm is already disabled.\033[0m"
fi

# Copy directories and apply Salt highstate
cp minion /etc/salt/minion
rm -rf /srv/salt/
mkdir -p /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate

# Update font cache
fc-cache
echo -e "\033[1;33mFont cache updated.\033[0m"

# Set the time and configure daily ntpdate cron job
ntpdate 0.pool.ntp.org
if ! crontab -l | grep -q "ntpdate 0.pool.ntp.org"; then
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/sbin/ntpdate 0.pool.ntp.org") | crontab -
    echo -e "\033[1;33mDaily ntpdate synchronization job added to cron.\033[0m"
else
    echo -e "\033[1;33mDaily ntpdate synchronization job already exists.\033[0m"
fi

echo -e "\033[1;33mProvisioning completed successfully.\033[0m"
