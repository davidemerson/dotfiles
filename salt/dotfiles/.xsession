# load Xresources file
xrdb -merge $HOME/.Xresources &

# Make the resolution 4k... you need to change this to appropriate display device if you have a different monitor setup
exec xrandr --output default --mode 3840x2160

# autolock after 10min
exec --no-startup-id xautolock -time 10 -locker 'i3lock -f -c 303030'

# no more bells
xset b off &

# black background
exec xsetroot -solid black

# run i3
exec i3
