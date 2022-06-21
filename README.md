# Workstation Configuration

This was last tested in OpenBSD 7.1

## Use

### Bootstrap

1. Run through standard install. You do want to use X, and you do want to allow xenodm to manage X. Make yourself a user.

2. Log in as your user. su to root.

2. Add your user to doas

3. Install curl, git, nano, and vmwindowhelper
```
pkg_add curl nano git vmwh
```

4. Add your user to doas
```
echo "permit nopass [username] as root" > /etc/doas.conf
```

4. Install salt-minion

```
curl -L https://bootstrap.saltstack.com -o install_salt.sh
sh install_salt.sh
```

5. Head back to your local user
```
exit
```

6. Grab this repo.
```
git clone https://github.com/davidemerson/dotfiles.git
```

7. Execute the execute.sh script, which refreshes the /srv/salt/ directory and applies highstate.
```
cd dotfiles
chmod 755 execute.sh
doas sh execute.sh
```

