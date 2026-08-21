#!/bin/sh
# waybar custom module: the address of whichever interface is actually carrying
# traffic, replacing waybar's built-in "network" module.
#
# Why replace a built-in: on a LAN whose router advertises an IPv6 ULA prefix
# alongside the v4 lease, waybar 0.12's network module renders the ULA, and the
# documented "family": "ipv4" option (whose default is already ipv4) does not
# change that. Its own debug log shows the bug plainly — it records the v4
# address and then overwrites it with each v6 address as those arrive:
#
#   network: eno2, new addr 10.62.14.40/24
#   network: eno2, new addr fd52:7a1d:4e54:4f18:3eec:efff:fe7e:6a95/64
#
# The result is a bar showing an address nothing is ever reached on. Reading the
# address here sidesteps the module entirely. Output matches the format strings
# the built-in was configured with, so the bar reads the same as before:
#
#   ethernet      eno2: 10.62.14.40/24
#   wireless      myssid (78%)
#   link, no IP   eno2 (No IP)
#   nothing up    Disconnected        (class "disconnected", as before)
#
# JSON output rather than plain text purely so the "disconnected" CSS class
# survives the switch — #network.disconnected became #custom-network.disconnected.

# Escape for JSON, then emit. An ESSID is arbitrary user-supplied text, so it
# gets escaped like anything else rather than trusted into the string.
emit() {
    esc=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    if [ -n "$2" ]; then
        printf '{"text":"%s","class":"%s"}\n' "$esc" "$2"
    else
        printf '{"text":"%s"}\n' "$esc"
    fi
}

# The interface holding the default route is the one worth naming. If there is
# no default route, fall back to the first physical interface with a carrier so
# a machine that is plugged in but has no gateway still reports something more
# useful than "Disconnected". Virtual interfaces are skipped for the same reason
# netgraph.sh skips them: they are not the link anyone means.
iface=$(ip -4 route show default 2>/dev/null | awk '$1 == "default" { print $5; exit }')

if [ -z "$iface" ]; then
    for dev in /sys/class/net/*; do
        name=${dev##*/}
        case $name in
            lo|veth*|docker*|br-*|virbr*|vnet*|vmnet*|zt*|tun*|tap*|wg*|ppp*) continue ;;
        esac
        [ "$(cat "$dev/carrier" 2>/dev/null)" = "1" ] || continue
        iface=$name
        break
    done
fi

if [ -z "$iface" ]; then
    emit "Disconnected" "disconnected"
    exit 0
fi

# Wireless: report ESSID and signal the way the built-in did. Both readers are
# optional — `iw` is not part of the desktop package set, and a machine without
# it simply falls through to showing the address instead, which is still true
# and still useful. Nothing here is fatal on a box with no wireless at all.
if [ -e "/sys/class/net/$iface/wireless" ] || [ -e "/sys/class/net/$iface/phy80211" ]; then
    essid=$(iwgetid -r "$iface" 2>/dev/null)
    [ -n "$essid" ] || essid=$(iw dev "$iface" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')

    if [ -n "$essid" ]; then
        # /proc/net/wireless reports link quality out of 70; waybar's
        # {signalStrength} is that same figure as a percentage. Column 3 carries
        # a trailing dot ("70.") which has to come off before the arithmetic.
        pct=$(awk -v want="$iface:" '$1 == want { q = $3; sub(/\./, "", q); printf "%d", q * 100 / 70; exit }' \
              /proc/net/wireless 2>/dev/null)
        if [ -n "$pct" ]; then
            emit "$essid ($pct%)"
        else
            emit "$essid"
        fi
        exit 0
    fi
fi

# `ip -o addr` field 4 is already "address/prefix", i.e. the built-in's
# {ipaddr}/{cidr} in one piece. scope global drops link-local noise.
addr=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{ print $4; exit }')

if [ -n "$addr" ]; then
    emit "$iface: $addr"
else
    emit "$iface (No IP)"
fi
