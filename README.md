# Workstation Configuration

This was last tested in OpenBSD 7.1

## Build Procedure

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

7. Grab this repo. If you're going to fork this and make your own dotfiles, you might want to make a step before the cloning bit where you scp your ssh key to the workstation you're building so you can read/write the repo, and then push your changes back live. If you're just getting a system running, though, read alone is enough here.
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

10. Keep salt-minion from starting (unnecessary since we're using salt-check). Use your editor of choice to comment out the pkg_scripts=salt_minion line in /etc/rc.conf.local.

11. Reboot
```
doas reboot
```

## Notes
* You'll note that my .muttrc and .msmtprc refer to ""~/.secrets/mailpass" for credentials. This is a one liner file containing my mail app password, keeping it out of this repo, and allowing me to do thing like encrypt it on disk. You can substitute any form of password management here, to accommodate your personal preferences.
* I've always hopped between Debian and OpenBSD for my personal workstation, with the majority of my time spent in Debian for practical reasons. I prefer OpenBSD philosophically, though, and at release 7.1, its warts have never been fewer, so it's what I'm running at the moment. If you used a previous version of this repo, it used to be Debian-centric until recently, and the current iteration will break some of that.

## Additional References
Check out how others have done this kind of thing, for inspiration and documentation:
* https://sohcahtoa.org.uk/openbsd.html
* https://jcs.org/2021/07/19/desktop
* https://daulton.ca/2018/08/openbsd-workstation/
* http://eradman.com/posts/openbsd-workstation.html
