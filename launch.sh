#!/bin/sh
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"
[ -f "$USERDATA_PATH/$PAK_NAME/debug" ] && set -x

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

ARCHITECTURE=arm
if [[ "$(uname -m)" == *"64"* ]]; then
    ARCHITECTURE=arm64
fi

export HOME="$USERDATA_PATH/$PAK_NAME"
export LD_LIBRARY_PATH="$PAK_DIR/lib:$LD_LIBRARY_PATH"
export PATH="$PAK_DIR/bin/$ARCHITECTURE:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"

show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

cleanup() {
    rm -f /tmp/stay_awake
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if ! command -v minui-presenter >/dev/null 2>&1; then
        show_message "minui-presenter not found" 2
        return 1
    fi

    delete_file="/tmp/delete-file"
    >"$delete_file"

    show_message "Cleaning up dot files..." "forever"

    cd "$SDCARD_PATH/"

    find . -maxdepth 1 \( -name ".Spotlight-V100" -o -name ".apDisk" -o -name ".fseventsd" -o -name ".TemporaryItems" -o -name ".Trash" -o -name ".Trashes" \) >> "$delete_file"
    find . -depth -type f \(  -name "._*" -o -name ".DS_Store" -o -name "*_cache[0-9].db" \) >> "$delete_file"
    find . -depth -type d -name "__MACOSX" >> "$delete_file"

    count=$(wc -l < "$delete_file")

    if [ "$count" -eq 0 ]; then
        killall minui-presenter >/dev/null 2>&1 || true
        show_message "Nothing to clean up." 2
    else
        while IFS= read -r file; do
            rm -rf "$file"
        done < "$delete_file"
        killall minui-presenter >/dev/null 2>&1 || true
        show_message "Cleanup complete. $count items deleted." 2
    fi
}

main "$@"
