#!/usr/bin/env bash
# =============================================================
#  Claude State Tracker — writes agent state for HUD status circle
#
#  States: working, waiting, error
#  HUD reads the state file + its age to derive idle (>5min)
#
#  Hook events:
#    PreToolUse          → working
#    PostToolUse         → working
#    PostToolUseFailure  → error
#    Stop                → waiting
# =============================================================

STATE_DIR="$HOME/.claude/hud-cache"
STATE_FILE="$STATE_DIR/claude-state"
mkdir -p "$STATE_DIR" 2>/dev/null

HOOK_EVENT="${CLAUDE_HOOK_EVENT:-}"

# Determine state from hook event type
STATE=""
case "$HOOK_EVENT" in
    PreToolUse|PostToolUse)
        STATE="working"
        ;;
    PostToolUseFailure)
        STATE="error"
        ;;
    Stop)
        STATE="waiting"
        ;;
    *)
        # For hook events passed via stdin (PostToolUse is the default)
        STATE="working"
        ;;
esac

# Write state + timestamp
echo "$STATE" > "$STATE_FILE"
