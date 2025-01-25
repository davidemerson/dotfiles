#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[1;33mThis script must be run as root.\033[0m"
   exit 1
fi

# Check if salt-minion is installed
if ! command -v salt-minion &> /dev/null; then
    echo "salt-minion not found. Installing via Salt Bootstrap script..."
    curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o bootstrap-salt.sh
    chmod +x bootstrap-salt.sh
    sudo ./bootstrap-salt.sh
else
    echo "salt-minion is already installed."
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

# Prompt for a username to provision dotfiles
echo -e "\033[1;33mEnter the username for which to provision dotfiles:\033[0m"
read USERNAME
if id -u "$USERNAME" >/dev/null 2>&1; then
    usermod -aG sudo "$USERNAME"
    echo -e "\033[1;33m$USERNAME added to sudoers.\033[0m"
else
    echo -e "\033[1;33mUser $USERNAME does not exist.\033[0m"
    exit 1
fi

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

# Set Salt pillar for the username
mkdir -p /srv/pillar
cat <<EOF > /srv/pillar/top.sls
base:
  '*':
    - user_config
EOF

cat <<EOF > /srv/pillar/user_config.sls
username: $USERNAME
EOF

# Configure Salt and apply highstate
cp minion /etc/salt/minion
rm -rf /srv/salt/
mkdir -p /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate

# Disable gdm from starting by default
if systemctl is-enabled gdm >/dev/null 2>&1; then
    systemctl disable gdm
    echo -e "\033[1;33mgdm disabled from starting by default.\033[0m"
else
    echo -e "\033[1;33mgdm is already disabled.\033[0m"
fi

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

echo -e "\033[1;33mProvisioning completed successfully for user $USERNAME.\033[0m"
