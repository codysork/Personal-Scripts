#!/bin/bash
# @file hotfiles.sh
# @author Cody Sork <codysork@gmail.com> with help from ChatGPT
# @created 2026-11-09
# @modified 2026-11-09
# @description Open frequently used files in Neovim using dmenu

#!/bin/bas# Configuration
HOTFILES="$HOME/.config/hotfiles/hotfiles.txt"
EDITOR="nvim"
TERMINAL="st"
DMENU="dmenu -i -l 10 -p 'Hotfiles:'"

# Options
NEW_TERMINAL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--terminal)
            NEW_TERMINAL=true
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo
            echo "Options:"
            echo "  -t, --terminal  Open Neovim in a new terminal"
            echo "  -h, --help      Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Check configuration
if [[ ! -f "$HOTFILES" ]]; then
    notify-send "Hotfiles" "Hotfiles list not found."
    exit 1
fi

# Display menu
selection=$(
    while IFS= read -r file; do
        file="${file/#\~/$HOME}"
        [[ -f "$file" ]] && printf '%s\n' "$file"
    done < "$HOTFILES" | eval "$DMENU"
)

# Open selected file
if [[ -n "$selection" ]]; then
    if $NEW_TERMINAL; then
        "$TERMINAL" -e "$EDITOR" "$selection" &
    else
        "$EDITOR" "$selection"
    fi
fi
