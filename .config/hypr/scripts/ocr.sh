#!/usr/bin/env bash
# Select a screen region, OCR it with tesseract, copy the text to the clipboard.
set -o pipefail

region=$(slurp) || exit 0   # Esc / cancelled selection
text=$(grim -g "$region" -s 2 - | tesseract - - -l "${OCR_LANG:-eng+mal}" 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/./,$!d')

if [[ -z "${text//[[:space:]]/}" ]]; then
	notify-send -a "OCR" -i edit-copy "OCR" "No text found"
	exit 1
fi

printf '%s' "$text" | wl-copy
notify-send -a "OCR" -i edit-copy "Copied text" "$(head -c 200 <<<"$text")"
