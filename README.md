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

6. Add your user to sudoers.
```
visudo
youruser ALL=(ALL:ALL) NOPASSWD:ALL
```

7. Log out of root. Log in as your user.

8. Clone your repo.
```
git clone https://github.com/davidemerson/dotfiles.git
```

9. Execute the execute.sh script, which refreshes the /srv/salt/ directory and applies highstate.
```
cd dotfiles
chmod 755 execute.sh
sudo ./execute.sh
```




## Stuff To Work On
- make your damn background black, just xsetroot or something in the i3 config exec section
- There's some great alias ideas here: https://github.com/jessfraz/dotfiles/blob/master/.aliases
- Install your fonts (make a state for copying them to the appropriate place)
- set nano as the update-alternatives text editor (I think this is a profile thing?)
- set lxterminal as the update-alternatives x-terminal-emulator (I think this is a profile thing?)
- generate an appropriate sources.list and add that to etc state https://debgen.simplylinux.ch/
- download latest sublime text and apply license. Also apply Sublime Text preferences.
- install package control on sublime (Sublime Pref)
- install package:colorsublime (Sublime Pref)
- install theme:flatland black (Sublime Pref)
- change default font to terminus 9 (Sublime Pref)
- install keybase
```
	curl -O https://prerelease.keybase.io/keybase_amd64.deb
	# if you see an error about missing `libappindicator1`
	# from the next command, you can ignore it, as the
	# subsequent command corrects it
	sudo dpkg -i keybase_amd64.deb
	sudo apt-get install -f
	run_keybase
```