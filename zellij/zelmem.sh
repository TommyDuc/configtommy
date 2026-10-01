#!/usr/bin/env bash
# zelmem.sh - memory usage per zellij pane (PSS + swap, including all child processes)
# Usage: zelmem.sh [-s session] [-c] [-n N]
#   -s session  only this session
#   -c          only the current session ($ZELLIJ_SESSION_NAME)
#   -n N        show only the top N panes
set -uo pipefail

only_sess="" top=0
while getopts "s:cn:h" o; do
    case $o in
        s) only_sess=$OPTARG ;;
        c) only_sess=${ZELLIJ_SESSION_NAME:?not inside a zellij session} ;;
        n) top=$OPTARG ;;
        *) sed -n '2,7p' "$0"; exit 1 ;;
    esac
done

# PSS + swap of one process in kB (shared memory split fairly, no double counting)
mem_kb() {
    local f="/proc/$1/smaps_rollup"
    [[ -r $f ]] || { echo 0; return; }
    awk '/^(Pss|Swap):/ {s += $2} END {print s + 0}' "$f" 2>/dev/null || echo 0
}

descendants() {
    local p
    for p in $(pgrep -P "$1"); do
        echo "$p"
        descendants "$p"
    done
}

rows=$(
for srv in $(pgrep -f 'zellij --server'); do
    sess=$(basename "$(ps -o args= -p "$srv" | awk '{print $NF}')")
    [[ -n $only_sess && $sess != "$only_sess" ]] && continue

    # pane id -> tab / title / floating
    declare -A info=()
    while IFS=$'\t' read -r id tab title fl; do
        info[$id]="$tab"$'\t'"$title$fl"
    done < <(zellij -s "$sess" action list-panes -a -j 2>/dev/null | jq -r '
        .[] | select(.is_plugin | not)
        | [.id, "\(.tab_position + 1):\(.tab_name)", .title,
           (if .is_floating then " [float]" else "" end)] | @tsv' 2>/dev/null)

    for root in $(pgrep -P "$srv"); do
        pane=$(tr '\0' '\n' < "/proc/$root/environ" 2>/dev/null \
               | sed -n 's/^ZELLIJ_PANE_ID=//p' | head -1)
        pane=${pane:-?}
        cwd=$(readlink "/proc/$root/cwd" 2>/dev/null)
        cwd=${cwd/#$HOME/\~}

        total=0 topkb=0 toppid=$root
        for p in $root $(descendants "$root"); do
            kb=$(mem_kb "$p")
            (( total += kb ))
            (( kb > topkb )) && { topkb=$kb; toppid=$p; }
        done
        topcmd=$(ps -o args= -p "$toppid" 2>/dev/null | cut -c1-45)

        # not in list-panes => pane was closed but its process is still alive
        loc=${info[$pane]:--$'\t'(orphan: pane closed)}
        printf '%s\t%s\t%s\t%s\t%s\t%s (%dM)\n' \
            "$total" "$sess" "$loc" "$pane" "${cwd:-?}" "$topcmd" $((topkb / 1024))
    done
    unset info
done | sort -t$'\t' -k1,1nr
)

[[ -z $rows ]] && { echo "No zellij panes found." >&2; exit 1; }

{
    printf 'MB\tSESSION\tTAB\tTITLE\tPANE\tCWD\tTOP PROCESS\n'
    if (( top > 0 )); then head -n "$top" <<<"$rows"; else cat <<<"$rows"; fi \
        | awk -F'\t' -v OFS='\t' '{$1 = sprintf("%.0f", $1 / 1024); print}'
} | column -t -s $'\t'

echo
awk -F'\t' '{s[$2] += $1} END {for (k in s) printf "%-20s %8.0f MB total\n", k, s[k] / 1024}' <<<"$rows" \
    | sort -k2,2nr
