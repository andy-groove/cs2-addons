#!/usr/bin/env bash
set -e

ROOT="/home/steam/cs2-dedicated"
GAMEINFO="$ROOT/game/csgo/gameinfo.gi"

CFG_SOURCE="/opt/agds/gamemode_competitive_server.cfg"
CFG_TARGET="$ROOT/game/csgo/cfg/gamemode_competitive_server.cfg"

BOTPROFILE_PATH="csgo/overrides/botprofile.vpk"
METAMOD_PATH="csgo/addons/metamod"

echo "pre-hook: applying AGDS customizations"

# ---------------------------------------------------
# gameinfo.gi
# ---------------------------------------------------
echo "pre-hook: checking gameinfo.gi: $GAMEINFO"

if [ ! -f "$GAMEINFO" ]; then
    echo "ERROR: gameinfo.gi not found: $GAMEINFO" >&2
    exit 1
fi

if [ ! -w "$GAMEINFO" ]; then
    echo "ERROR: gameinfo.gi is not writable: $GAMEINFO" >&2
    exit 1
fi

# Прибираємо старі дублікати, якщо вони були додані раніше.
# Потім додаємо потрібні рядки знову у правильне місце.
TMP_CLEAN="$(mktemp)"

grep -Ev "^[[:space:]]*Game[[:space:]]+${BOTPROFILE_PATH//\//\\/}[[:space:]]*$|^[[:space:]]*Game[[:space:]]+${METAMOD_PATH//\//\\/}[[:space:]]*$" \
    "$GAMEINFO" > "$TMP_CLEAN"

TMP_FINAL="$(mktemp)"

awk -v botprofile="$BOTPROFILE_PATH" -v metamod="$METAMOD_PATH" '
    BEGIN {
        in_searchpaths = 0
        inserted = 0
    }

    /^[[:space:]]*SearchPaths[[:space:]]*$/ {
        in_searchpaths = 1
        print
        next
    }

    in_searchpaths && !inserted && /^[[:space:]]*\{/ {
        print

        # ВАЖЛИВО:
        # Порядок має бути до Game csgo, щоб overrides і Metamod мали пріоритет.
        print "\t\t\tGame\t" botprofile
        print "\t\t\tGame\t" metamod

        inserted = 1
        next
    }

    {
        print
    }

    END {
        if (!inserted) {
            exit 42
        }
    }
' "$TMP_CLEAN" > "$TMP_FINAL" || {
    rm -f "$TMP_CLEAN" "$TMP_FINAL"
    echo "ERROR: SearchPaths block not found in gameinfo.gi" >&2
    exit 1
}

cat "$TMP_FINAL" > "$GAMEINFO"
rm -f "$TMP_CLEAN" "$TMP_FINAL"

echo "pre-hook: current AGDS gameinfo.gi entries:"
grep -nE "csgo/overrides/botprofile.vpk|csgo/addons/metamod" "$GAMEINFO" || {
    echo "ERROR: required gameinfo.gi entries were not added" >&2
    exit 1
}

# ---------------------------------------------------
# gamemode_competitive_server.cfg
# ---------------------------------------------------
echo "pre-hook: copying gamemode_competitive_server.cfg"

if [ -f "$CFG_SOURCE" ]; then
    cp "$CFG_SOURCE" "$CFG_TARGET"
    chmod 664 "$CFG_TARGET"
    echo "pre-hook: gamemode_competitive_server.cfg copied to $CFG_TARGET"
else
    echo "ERROR: config source not found: $CFG_SOURCE" >&2
    exit 1
fi

echo "pre-hook: finished"
