# Workstation Configuration

This was last tested in OpenBSD 7.1

## Use

### Bootstrap

1. Run through standard install. You do want to use X, and you do want to allow xenodm to manage X. Make yourself a user.

2. Log in as your user. su to root.

3. Install curl, git, nano, and vmwindowhelper
```
pkg_add curl nano git vmwh
```

4. Add your user to doas
```
echo "permit nopass [username] as root" > /etc/doas.conf
```

5. Install salt-minion

```
curl -L https://bootstrap.saltstack.com -o install_salt.sh
sh install_salt.sh
```

6. Head back to your local user
```
exit
```

7. Grab this repo.
```
git clone https://github.com/davidemerson/dotfiles.git
```

8. Execute the execute.sh script, which refreshes the /srv/salt/ directory and applies highstate.
```
cd dotfiles
chmod 755 execute.sh
doas sh execute.sh
```

9. Clean things up
```
rm ~/install_salt.sh
```

9. Reboot
```
doas reboot
```

Note: Of course, if you're going to fork this and make your own dotfiles, you might want to make a step before the cloning bit where you upload your ssh key so you can read/write the repo, and then push your changes back live. If you're just getting a system running, though, read alone is enough here.
