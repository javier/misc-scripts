#!/bin/bash
#
# Spotlight reset for modern macOS (APFS: read-only "/" firmlinked to the
# real "/System/Volumes/Data" volume that holds your files).
#
# Why the old version broke things:
#   - It used `mdutil -a` (all volumes) and toggled off/on rapidly. On the
#     firmlinked Data volume that wedges indexing into
#     "Error: unknown indexing state" / "unable to perform operation (-405)".
#   - It tried to manage "/", which is the read-only SYSTEM volume with almost
#     nothing to index. Your files are on /System/Volumes/Data.
#
# This version targets the Data volume only, wipes the store in place with
# `mdutil -X` (you CANNOT `rm` .Spotlight-V100 -- SIP blocks it), and clears a
# wedged daemon with `killall mds` (NOT `launchctl kickstart/bootout`, which SIP
# blocks). `mds` has KeepAlive, so launchd respawns it instantly and it
# re-registers the volume -- the no-reboot equivalent of restarting.

set -u

VOL="/System/Volumes/Data"

if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

echo "==> Disabling indexing on $VOL"
mdutil -i off "$VOL"

echo "==> Erasing index store in place (never rm .Spotlight-V100 -- SIP blocks it)"
mdutil -X "$VOL"

echo "==> Restarting mds to clear any wedged volume registration"
# launchctl kickstart/bootout are SIP-blocked for Apple daemons; killall works
# because mds has KeepAlive and launchd respawns it immediately.
killall mds 2>/dev/null
killall mds_stores 2>/dev/null
echo "    waiting for mds to respawn and re-register volumes..."
sleep 10

echo "==> Re-enabling and rebuilding"
mdutil -i on "$VOL"
mdutil -E "$VOL"

echo "==> Status"
mdutil -s "$VOL"

# Real index counts. Note: mdfind takes these as literal predicates, so the
# obvious-looking "== '*'" or "== 'public.item'" match almost nothing and
# always read ~0 even on a healthy index -- do NOT use them as health checks.
# These predicates actually count populated items:
echo "    apps indexed:  $(mdfind -count "kMDItemKind == 'Application'")"
echo "    total indexed: $(mdfind -count "kMDItemContentModificationDate > '2001-01-01 00:00:00 +0000'")"

echo
echo "Indexing rebuilds in the background (minutes to hours); the totals above"
echo "climb as it runs. Re-check anytime with:"
echo "    mdutil -s $VOL"
echo "    mdfind -count \"kMDItemKind == 'Application'\""
echo "    mdfind -count \"kMDItemContentModificationDate > '2001-01-01 00:00:00 +0000'\""
echo
echo "If status above still says 'unknown' / error -405, run this script once"
echo "more. If it STILL won't clear, mds is SIP-protected on this OS and a"
echo "reboot is the only remaining option."
