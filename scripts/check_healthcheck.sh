#!/bin/sh
# Nagios-compatible view of the nnix healthcheck, for snmpd `extend` ->
# LibreNMS. Reads the state file healthcheck writes rather than re-running the
# probes, so monitoring and the journal can never disagree about this host's
# health, and an SNMP poll never triggers ipmitool/smartctl work.
#
# Exit: 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN

STATE=/var/lib/nnix/healthcheck.state
# healthcheck.timer is daily; allow two missed runs before calling it stale.
STALE_SEC=172800

[ -r "$STATE" ] || { echo "UNKNOWN: $STATE missing — has healthcheck run?"; exit 3; }

ts=0; worst=3; issues=0; summary=""
while IFS='=' read -r k v; do
    case "$k" in
        ts) ts=$v ;; worst) worst=$v ;; issues) issues=$v ;; summary) summary=$v ;;
    esac
done < "$STATE"

# snmpd `extend` output containing non-ASCII comes back as a Hex-STRING, which
# LibreNMS renders as raw bytes. The journal keeps the pretty text; this view
# gets a plain-ASCII transliteration of it.
summary=$(printf '%s' "$summary" | sed 's/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g' | LC_ALL=C tr -cd '\11\12\15\40-\176')

age=$(( $(date +%s) - ts ))
if [ "$age" -gt "$STALE_SEC" ]; then
    echo "UNKNOWN: healthcheck result is ${age}s old — healthcheck.timer not running?"
    exit 3
fi

case "$worst" in
    0) echo "OK: $summary"; exit 0 ;;
    1) echo "WARNING: $issues issue(s): $summary"; exit 1 ;;
    2) echo "CRITICAL: $issues issue(s): $summary"; exit 2 ;;
    *) echo "UNKNOWN: unrecognised state in $STATE"; exit 3 ;;
esac
