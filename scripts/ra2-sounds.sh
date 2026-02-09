#!/usr/bin/env bash
# =============================================================
#  Red Alert 2 Sound Effects for Claude Code
#  Reads hook JSON from stdin, plays appropriate RA2 sound
#
#  Sound mapping:
#    Task completed     → construction_complete
#    Build success      → acknowledged
#    Tests pass         → affirmative
#    Git commit         → yes_commander / sir_yes_sir / da
#    Git push           → moving_out
#    Subagent spawned   → kirov_reporting / training / unit_ready
#    Deploy triggered   → building
#    npm install        → reinforcements_have_arrived
#    Error/failure      → unable_to_comply
#    Session stop       → mission_accomplished
#    Notification       → new_construction_options
# =============================================================

SOUNDS_DIR="$HOME/.claude/sounds"

# -----------------------------------------------------------
#  Audio playback (cross-platform)
# -----------------------------------------------------------
play() {
    local base="$SOUNDS_DIR/$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        if [[ -f "${base}.mp3" ]]; then
            afplay "${base}.mp3" &
        elif [[ -f "${base}.aiff" ]]; then
            afplay "${base}.aiff" &
        fi
    else
        # Linux — try mpv, paplay, aplay in order
        local file=""
        [[ -f "${base}.mp3" ]] && file="${base}.mp3"
        [[ -z "$file" && -f "${base}.aiff" ]] && file="${base}.aiff"
        [[ -z "$file" ]] && return

        if command -v mpv &>/dev/null; then
            mpv --no-terminal "$file" &
        elif command -v paplay &>/dev/null; then
            paplay "$file" &
        elif command -v aplay &>/dev/null; then
            aplay "$file" &
        fi
    fi
}

# Pick a random sound from a list
play_random() {
    local sounds=("$@")
    local idx=$(( RANDOM % ${#sounds[@]} ))
    play "${sounds[$idx]}"
}

# -----------------------------------------------------------
#  Parse hook JSON from stdin
# -----------------------------------------------------------
INPUT=$(cat)

HOOK_EVENT="${CLAUDE_HOOK_EVENT:-}"
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tool_input',{})))" 2>/dev/null)
TOOL_OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_output','')[:500])" 2>/dev/null)
STOP_REASON=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_reason',''))" 2>/dev/null)

# --- PostToolUse Events ---

if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then
    if echo "$TOOL_INPUT" | grep -q '"completed"'; then
        play "construction_complete"
        exit 0
    fi
fi

if [[ "$TOOL_NAME" == "Bash" ]]; then
    CMD=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null)

    # Git commit
    if echo "$CMD" | grep -q 'git commit'; then
        if echo "$TOOL_OUTPUT" | grep -qiE '\[main|create mode|file changed|insertion'; then
            play_random "yes_commander" "sir_yes_sir" "da"
            exit 0
        fi
    fi

    # Git push
    if echo "$CMD" | grep -q 'git push'; then
        if ! echo "$TOOL_OUTPUT" | grep -qi 'rejected\|error\|fatal'; then
            play "moving_out"
            exit 0
        else
            play "unable_to_comply"
            exit 0
        fi
    fi

    # Build success
    if echo "$CMD" | grep -qE 'npm run build|vite build|tsc'; then
        if echo "$TOOL_OUTPUT" | grep -qiE 'built in|✓|successfully'; then
            play "acknowledged"
            exit 0
        elif echo "$TOOL_OUTPUT" | grep -qiE 'error|failed|FAIL'; then
            play "unable_to_comply"
            exit 0
        fi
    fi

    # Test success
    if echo "$CMD" | grep -qE 'vitest|jest|npm run test|npm test|pytest|cargo test'; then
        if echo "$TOOL_OUTPUT" | grep -qiE 'passed|✓.*tests|tests passed'; then
            play "affirmative"
            exit 0
        elif echo "$TOOL_OUTPUT" | grep -qiE 'failed|FAIL'; then
            play "unable_to_comply"
            exit 0
        fi
    fi

    # Deploy
    if echo "$CMD" | grep -qE 'vercel|deploy|fly deploy|railway'; then
        play "building"
        exit 0
    fi

    # Package install
    if echo "$CMD" | grep -qE 'npm install|npm i |yarn add|pnpm add|pip install|cargo add'; then
        if ! echo "$TOOL_OUTPUT" | grep -qi 'ERR!\|error'; then
            play "reinforcements_have_arrived"
            exit 0
        fi
    fi
fi

# Subagent spawned
if [[ "$TOOL_NAME" == "Task" ]]; then
    play_random "kirov_reporting" "training" "unit_ready"
    exit 0
fi

# --- Stop Event ---
if [[ -n "$STOP_REASON" ]] || [[ "$HOOK_EVENT" == "Stop" ]]; then
    play "mission_accomplished"
    exit 0
fi

# --- Notification Event ---
if [[ "$HOOK_EVENT" == "Notification" ]] || [[ "$HOOK_EVENT" == "NotificationAfterMessage" ]]; then
    play "new_construction_options"
    exit 0
fi

exit 0
