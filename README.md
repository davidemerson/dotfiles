# Workstation Configuration

Get it in to this format:
https://github.com/jacksoncage/salt-workstation

This was tested last in Debian 10.8.

## Use

### Bootstrap

1. Run through standard install. Add your user, and partition whole disk (all in one) with encrypted LVM. Install only "Standard System Utilities".

2. Log in as root.

3. Install curl, git, sudo, and nano.
```
apt install -y curl nano git sudo
```

4. Install salt-minion

```
curl -L https://bootstrap.saltstack.com -o install_salt.sh
sh install_salt.sh
```

5. Set salt to run masterless. To instruct the minion to not look for a master, the file_client configuration option needs to be set in the minion configuration file. In `/etc/salt/minion` set `file_client: local`

*NOTE: When running Salt in masterless mode, do not run the salt-minion daemon. Otherwise, it will attempt to connect to a master and fail. The salt-call command stands on its own and does not need the salt-minion daemon.*

6. Add you user to sudoers.
```
visudo
youruser ALL=(ALL:ALL) NOPASSWD:ALL
```

7. Log out of root. Log in as your user.

8. Clone your repo.
```
git clone https://github.com/davidemerson/dotfiles.git
```

### Apply State

- All of them at once:
```
salt-call --local state.highstate -l debug
```
- Individually:
```
salt-call --local state.sls base -l debug
```


install keybase
	curl -O https://prerelease.keybase.io/keybase_amd64.deb
	# if you see an error about missing `libappindicator1`
	# from the next command, you can ignore it, as the
	# subsequent command corrects it
	sudo dpkg -i keybase_amd64.deb
	sudo apt-get install -f
	run_keybase

git clone keybase://private/syzygetic/config.workstation
sudo cp ~/config.workstation/d3e_etc_files/ntp.conf /etc/ntp.conf

sudo systemctl start ntp
sudo systemctl enable ntp

cd config.workstation
./refresh_stow.sh

sudo update-alternatives --config editor
	select nano

<<<<<<< HEAD
nano /etc/passwd and change your default shell to /bin/dash

visudo
	david	ALL=(ALL:ALL) NOPASSWD:ALL
=======
sudo update-alternatives --config x-terminal-emulator
	select lxterminal
>>>>>>> e58c47b173401b9db2a65f5598674d6d3f02e080

## get this into stow and add cp line
/etc/X11/xdm/Xresources ### guide https://wiki.archlinux.org/index.php/XDM
	- use xfontsel to tell it terminus
	- comment out logo items
	- change greeting to purefoy
	- change namePrompt to user
	- change passwdPrompt to pass:
	- change fail to wrong

## if the one in config.workstation/d3e_etc_files doesn't work, generate an appropriate sources.list: https://debgen.simplylinux.ch/
sudo cp ~/config.workstation/d3e_etc_files/sources.list /etc/apt/sources.list
Keys to install (as root)
	wget http://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb && dpkg -i deb-multimedia-keyring_2016.8.1_all.deb
	wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -

sudo apt-get update
sudo apt-get dist-upgrade

sudo pip install py3status #docs: https://github.com/ultrabug/py3status

sudo apt-get install sublime-text google-chrome-stable

grab lsd tool from here:
	(https://github.com/Peltoche/lsd) and dpkg -i it.

add license to subl

----- BEGIN LICENSE -----
Platform Operations
4 User License
EA7E-908542
B147E7D5 826E76E5 67D2CFCA 6DFC9F0B
3BACA731 658059B2 A06C4F03 0F0D15B5
522F0F78 8BAE6492 C75A0C7B B176A062
23FA7654 4D9CEE16 35D80DD4 2EE179ED
DD96E051 6DDDDC25 6791F6A2 2A0FD151
04D77266 EFA61F57 2CF6EB11 55CE150C
9E21AFE2 B5F5CF8D 88EABCBA 7AC4183D
A4205474 231324E5 FFDF42B8 19F69543
------ END LICENSE ------

install package control on sublime

install package:colorsublime

install theme:flatland black

change default font to terminus 9

### Configure Yubikey (guide https://support.yubico.com/support/solutions/articles/15000011356-ubuntu-linux-login-guide-u2f)
sudo apt-get install libpam-u2f
insert the key
mkdir ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys
sudo nano /etc/pam.d/sudo
	add "auth	required	pam_u2f.so" at eof
sudo nano /etc/pam.d/xdm
	add "auth	required	pam_u2f.so" at eof
sudo nano /etc/pam.d/i3lock
	add "auth	required	pam_u2f.so" at eof

###download and install yubico management tools
sudo apt-get install yubikey-manager
	test with: ykman oath code
	(should generate codes for all your tokens)

download and install the appgate client: https://www.cryptzone.com/downloadcenter/appgate-sdp

log in to appgate
https://cyxsdp.cyxtera.com/eyJzcGEiOnsibW9kZSI6IlRDUCIsIm5hbWUiOiJDWVhTRFAiLCJrZXkiOiIwZWRiMzk4MGQ1ZGI1NWYyOWU5YzlmNmRhNWZiMzQ5NGRhMmM1Nzg2ZGJiM2Y5YzE2OTM3MzNkYjI4ZjkxOTRhIn19

files to commit:
/etc/X11/xdm/Xresources 
/etc/apt/sources.list
sublime text user preferences
/etc/pam.d/sudo
