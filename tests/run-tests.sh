#!/usr/bin/env bash
# =============================================================
#  vibe-command test runner
#  Lightweight bash test framework -- no external dependencies
#
#  Usage: bash tests/run-tests.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}FAIL${NC} $1"
    [[ -n "${2:-}" ]] && echo -e "       ${RED}$2${NC}"
}

skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    echo -e "  ${YELLOW}SKIP${NC} $1"
}

# -----------------------------------------------------------
#  Test: Repository structure
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Repository Structure ===${NC}"

test_file_exists() {
    local file="$1" desc="$2"
    if [[ -f "$REPO_DIR/$file" ]]; then
        pass "$desc ($file)"
    else
        fail "$desc ($file)" "File not found"
    fi
}

test_dir_exists() {
    local dir="$1" desc="$2"
    if [[ -d "$REPO_DIR/$dir" ]]; then
        pass "$desc ($dir)"
    else
        fail "$desc ($dir)" "Directory not found"
    fi
}

test_file_exists "install.sh" "Installer exists"
test_file_exists "uninstall.sh" "Uninstaller exists"
test_file_exists "README.md" "README exists"
test_file_exists "LICENSE" "License exists"
test_file_exists "CHANGELOG.md" "Changelog exists"
test_file_exists "CONTRIBUTING.md" "Contributing guide exists"

# -----------------------------------------------------------
#  Test: Scripts are executable and have shebangs
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Script Headers ===${NC}"

test_script_header() {
    local file="$1" desc="$2"
    if [[ ! -f "$REPO_DIR/$file" ]]; then
        fail "$desc" "File not found: $file"
        return
    fi
    local first_line
    first_line=$(head -1 "$REPO_DIR/$file")
    if [[ "$first_line" == "#!/usr/bin/env bash" ]] || [[ "$first_line" == "#!/bin/bash" ]]; then
        pass "$desc has bash shebang"
    else
        fail "$desc has bash shebang" "Got: $first_line"
    fi
}

test_script_header "install.sh" "install.sh"
test_script_header "uninstall.sh" "uninstall.sh"
test_script_header "scripts/tmux-hud.sh" "tmux-hud.sh"
test_script_header "scripts/sound-hook.sh" "sound-hook.sh"
test_script_header "scripts/claude-state.sh" "claude-state.sh"
test_script_header "scripts/flag-theme.sh" "flag-theme.sh"
test_script_header "scripts/ra2-sounds.sh" "ra2-sounds.sh"

# -----------------------------------------------------------
#  Test: Sound packs have expected files
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Sound Pack: Red Alert 2 ===${NC}"

RA2_DIR="$REPO_DIR/sounds/ra2"
RA2_EXPECTED=(
    acknowledged affirmative at_your_service battle_control_online
    building construction_complete da kirov_reporting
    mission_accomplished moving_out new_construction_options
    reinforcements_have_arrived sir_yes_sir training
    unable_to_comply unit_ready yes_commander
)

for sound in "${RA2_EXPECTED[@]}"; do
    if [[ -f "$RA2_DIR/${sound}.mp3" ]] || [[ -f "$RA2_DIR/${sound}.aiff" ]]; then
        pass "RA2 sound: $sound"
    else
        fail "RA2 sound: $sound" "Not found in $RA2_DIR"
    fi
done

echo -e "\n${BOLD}=== Sound Pack: Heroes of Might and Magic III ===${NC}"

HOMM3_DIR="$REPO_DIR/sounds/homm3"
HOMM3_EXPECTED=(
    angel_summon build cavalry_move dragon_roar negative_luck
    phoenix_cast positive_luck quest_received recruit
    ship_move spell_cast town_screen treasure victory
)

for sound in "${HOMM3_EXPECTED[@]}"; do
    if [[ -f "$HOMM3_DIR/${sound}.mp3" ]]; then
        pass "HoMM3 sound: $sound"
    else
        fail "HoMM3 sound: $sound" "Not found in $HOMM3_DIR"
    fi
done

# -----------------------------------------------------------
#  Test: Sound maps resolve all events for both packs
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Sound Maps ===${NC}"

source "$REPO_DIR/config/sound-maps.sh"

EVENTS=(startup task_complete build_success build_fail tests_pass tests_fail
        git_commit git_push git_push_fail deploy pkg_install subagent
        error session_stop notification)

for pack in ra2 homm3; do
    for event in "${EVENTS[@]}"; do
        local_sound=$(get_sound "$pack" "$event")
        if [[ -n "$local_sound" ]]; then
            pass "sound_map: $pack/$event -> $local_sound"
        else
            fail "sound_map: $pack/$event" "No mapping found"
        fi
    done
done

# -----------------------------------------------------------
#  Test: Flag colors resolve for known countries
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Flag Colors ===${NC}"

source "$REPO_DIR/themes/flags.sh"

COUNTRIES=(US IL DE GB JP BR UA FR IN AU)

for cc in "${COUNTRIES[@]}"; do
    colors=$(get_flag_colors "$cc")
    read -r p s l a e <<< "$colors"
    if [[ -n "$p" ]] && [[ -n "$s" ]] && [[ -n "$l" ]] && [[ -n "$a" ]] && [[ -n "$e" ]]; then
        pass "flag_colors: $cc -> $p/$s/$l/$a $e"
    else
        fail "flag_colors: $cc" "Incomplete color set: $colors"
    fi
done

# Test international fallback
colors=$(get_flag_colors "XX")
read -r p s l a e <<< "$colors"
if [[ "$e" == *"🌍"* ]] || [[ -n "$p" ]]; then
    pass "flag_colors: XX (unknown) falls back to INTL"
else
    fail "flag_colors: XX (unknown)" "No fallback colors"
fi

# -----------------------------------------------------------
#  Test: Config file parsing
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Config Parsing ===${NC}"

# Create a temp config for testing
TEMP_CONF=$(mktemp)
cat > "$TEMP_CONF" <<'CONF'
sound_pack=homm3
visual_theme=matrix
country=JP
powerline_glyphs=true
CONF

# Test reading values
test_config_read() {
    local key="$1" expected="$2" desc="$3"
    local val
    val=$(grep "^${key}=" "$TEMP_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [[ "$val" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc" "Expected '$expected', got '$val'"
    fi
}

test_config_read "sound_pack" "homm3" "Config reads sound_pack"
test_config_read "visual_theme" "matrix" "Config reads visual_theme"
test_config_read "country" "JP" "Config reads country"
test_config_read "powerline_glyphs" "true" "Config reads powerline_glyphs"

# Test missing key returns empty
missing_val=$(grep "^nonexistent=" "$TEMP_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ' || true)
if [[ -z "$missing_val" ]]; then
    pass "Config returns empty for missing key"
else
    fail "Config returns empty for missing key" "Got: $missing_val"
fi

rm -f "$TEMP_CONF"

# -----------------------------------------------------------
#  Test: Default config has all required keys
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Default Config Template ===${NC}"

DEFAULT_CONF="$REPO_DIR/config/vibe-command.conf.default"
REQUIRED_KEYS=(sound_pack visual_theme country powerline_glyphs)

for key in "${REQUIRED_KEYS[@]}"; do
    if grep -q "^${key}=" "$DEFAULT_CONF"; then
        pass "Default config has key: $key"
    else
        fail "Default config has key: $key" "Not found in $DEFAULT_CONF"
    fi
done

# -----------------------------------------------------------
#  Test: tmux templates have required placeholders
# -----------------------------------------------------------
echo -e "\n${BOLD}=== tmux Templates ===${NC}"

TEMPLATES=(
    "config/tmux-flag.conf.template"
    "config/tmux-matrix.conf.template"
    "config/tmux-scifi.conf.template"
)

for template in "${TEMPLATES[@]}"; do
    if [[ ! -f "$REPO_DIR/$template" ]]; then
        fail "Template exists: $template" "Not found"
        continue
    fi
    pass "Template exists: $template"

    # Check for HUD script references
    if grep -q "tmux-hud.sh" "$REPO_DIR/$template"; then
        pass "Template references tmux-hud.sh: $template"
    else
        fail "Template references tmux-hud.sh: $template"
    fi
done

# -----------------------------------------------------------
#  Test: Hooks template has required events
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Hooks Template ===${NC}"

HOOKS_TEMPLATE="$REPO_DIR/config/hooks.json.template"
HOOK_EVENTS=(PreToolUse PostToolUse PostToolUseFailure Stop Notification)

for event in "${HOOK_EVENTS[@]}"; do
    if grep -q "\"$event\"" "$HOOKS_TEMPLATE"; then
        pass "Hooks template has event: $event"
    else
        fail "Hooks template has event: $event"
    fi
done

# -----------------------------------------------------------
#  Test: HUD dispatch handles all known components
# -----------------------------------------------------------
echo -e "\n${BOLD}=== HUD Components ===${NC}"

HUD_COMPONENTS=(worktime tokens agents commits branch status context_pct git_sync claude_state all)

for comp in "${HUD_COMPONENTS[@]}"; do
    if grep -q "\"$comp\"" "$REPO_DIR/scripts/tmux-hud.sh" || grep -q "$comp)" "$REPO_DIR/scripts/tmux-hud.sh"; then
        pass "HUD handles component: $comp"
    else
        fail "HUD handles component: $comp"
    fi
done

# -----------------------------------------------------------
#  Test: Sound disclaimers exist
# -----------------------------------------------------------
echo -e "\n${BOLD}=== Sound Disclaimers ===${NC}"

test_file_exists "sounds/ra2/DISCLAIMER.md" "RA2 disclaimer exists"
test_file_exists "sounds/homm3/DISCLAIMER.md" "HoMM3 disclaimer exists"

# -----------------------------------------------------------
#  Summary
# -----------------------------------------------------------
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo -e "${BOLD}═══════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS: $PASS_COUNT${NC}  ${RED}FAIL: $FAIL_COUNT${NC}  ${YELLOW}SKIP: $SKIP_COUNT${NC}  TOTAL: $TOTAL"
echo -e "${BOLD}═══════════════════════════════════════${NC}"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
