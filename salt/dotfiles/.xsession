# load Xresources file
xrdb -merge $HOME/.Xresources &

# no more bells
xset b off &

# run i3
exec i3
