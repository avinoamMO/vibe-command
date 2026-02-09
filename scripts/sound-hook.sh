#!/usr/bin/env bash
# =============================================================
#  Sound Hook — Multi-pack sound effects for Claude Code
#  Reads hook JSON from stdin, maps events to abstract sound names,
#  then resolves to filenames via the active sound pack.
#
#  Config: ~/.claude/vibe-command.conf (sound_pack=ra2|homm3)
# =============================================================

# -----------------------------------------------------------
#  Config
# -----------------------------------------------------------
CONF_FILE="$HOME/.claude/vibe-command.conf"
SOUND_PACK="ra2"  # default

if [[ -f "$CONF_FILE" ]]; then
    local_pack=$(grep '^sound_pack=' "$CONF_FILE" 2>/dev/null | cut -d= -f2 | tr -d ' ')
    [[ -n "$local_pack" ]] && SOUND_PACK="$local_pack"
fi

SOUNDS_DIR="$HOME/.claude/sounds/$SOUND_PACK"

# Source the sound mapping
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MAPS_FILE="$REPO_DIR/config/sound-maps.sh"

# Try installed location first, then repo location
if [[ -f "$HOME/.vibe-command/config/sound-maps.sh" ]]; then
    source "$HOME/.vibe-command/config/sound-maps.sh"
elif [[ -f "$MAPS_FILE" ]]; then
    source "$MAPS_FILE"
else
    # Inline fallback — just play from SOUNDS_DIR directly
    get_sound_random() { echo "$2"; }
fi

# -----------------------------------------------------------
#  Audio playback (cross-platform)
# -----------------------------------------------------------
play() {
    local base="$SOUNDS_DIR/$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ -f "${base}.mp3" ]]; then
            afplay "${base}.mp3" &
        elif [[ -f "${base}.aiff" ]]; then
            afplay "${base}.aiff" &
        fi
    else
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

# Play an abstract event sound
play_event() {
    local event="$1"
    local filename
    filename=$(get_sound_random "$SOUND_PACK" "$event")
    [[ -n "$filename" ]] && play "$filename"
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
        play_event "task_complete"
        exit 0
    fi
fi

if [[ "$TOOL_NAME" == "Bash" ]]; then
    CMD=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null)

    # Git commit
    if echo "$CMD" | grep -q 'git commit'; then
        if echo "$TOOL_OUTPUT" | grep -qiE '\[main|create mode|file changed|insertion'; then
            play_event "git_commit"
            exit 0
        fi
    fi

    # Git push
    if echo "$CMD" | grep -q 'git push'; then
        if ! echo "$TOOL_OUTPUT" | grep -qi 'rejected\|error\|fatal'; then
            play_event "git_push"
            exit 0
        else
            play_event "git_push_fail"
            exit 0
        fi
    fi

    # Build success
    if echo "$CMD" | grep -qE 'npm run build|vite build|tsc'; then
        if echo "$TOOL_OUTPUT" | grep -qiE 'built in|✓|successfully'; then
            play_event "build_success"
            exit 0
        elif echo "$TOOL_OUTPUT" | grep -qiE 'error|failed|FAIL'; then
            play_event "build_fail"
            exit 0
        fi
    fi

    # Test success
    if echo "$CMD" | grep -qE 'vitest|jest|npm run test|npm test|pytest|cargo test'; then
        if echo "$TOOL_OUTPUT" | grep -qiE 'passed|✓.*tests|tests passed'; then
            play_event "tests_pass"
            exit 0
        elif echo "$TOOL_OUTPUT" | grep -qiE 'failed|FAIL'; then
            play_event "tests_fail"
            exit 0
        fi
    fi

    # Deploy
    if echo "$CMD" | grep -qE 'vercel|deploy|fly deploy|railway'; then
        play_event "deploy"
        exit 0
    fi

    # Package install
    if echo "$CMD" | grep -qE 'npm install|npm i |yarn add|pnpm add|pip install|cargo add'; then
        if ! echo "$TOOL_OUTPUT" | grep -qi 'ERR!\|error'; then
            play_event "pkg_install"
            exit 0
        fi
    fi
fi

# Subagent spawned
if [[ "$TOOL_NAME" == "Task" ]]; then
    play_event "subagent"
    exit 0
fi

# --- Stop Event ---
if [[ -n "$STOP_REASON" ]] || [[ "$HOOK_EVENT" == "Stop" ]]; then
    play_event "session_stop"
    exit 0
fi

# --- Notification Event ---
if [[ "$HOOK_EVENT" == "Notification" ]] || [[ "$HOOK_EVENT" == "NotificationAfterMessage" ]]; then
    play_event "notification"
    exit 0
fi

exit 0
