#!/bin/bash
STATE=~/callping/.guard_fail
if timeout 3 bash -c "</dev/tcp/<HOST>/22" 2>/dev/null; then
    rm -f "$STATE"
    systemctl --user is-active --quiet callping-api || systemctl --user start callping-api
else
    n=$(cat "$STATE" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$STATE"
    if [ "$n" -ge 2 ] && systemctl --user is-active --quiet callping-api; then
        systemctl --user stop callping-api
    fi
fi
exit 0
