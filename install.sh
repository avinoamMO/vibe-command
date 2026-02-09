#!/usr/bin/env bash
# =============================================================
#  vibe-command installer
#  One-command setup: curl -fsSL <url>/install.sh | bash
# =============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.vibe-command"
REPO_URL="https://github.com/avinoamMO/vibe-command.git"

# -----------------------------------------------------------
#  Helpers
# -----------------------------------------------------------
info()    { echo -e "${CYAN}[vibe-command]${NC} $*"; }
success() { echo -e "${GREEN}[vibe-command]${NC} $*"; }
warn()    { echo -e "${YELLOW}[vibe-command]${NC} $*"; }
error()   { echo -e "${RED}[vibe-command]${NC} $*" >&2; }

check_dep() {
    if ! command -v "$1" &>/dev/null; then
        error "Required: $1 not found. Please install it first."
        return 1
    fi
}

read_config() {
    local key="$1" default="$2"
    local conf="$HOME/.claude/vibe-command.conf"
    if [[ -f "$conf" ]]; then
        local val
        val=$(grep "^${key}=" "$conf" 2>/dev/null | cut -d= -f2 | tr -d ' ')
        [[ -n "$val" ]] && echo "$val" && return
    fi
    echo "$default"
}

# -----------------------------------------------------------
#  Banner
# -----------------------------------------------------------
echo ""
echo -e "${RED}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}  ║${NC}  ${BOLD}VIBE-COMMAND${NC}                               ${RED}║${NC}"
echo -e "${RED}  ║${NC}  ${CYAN}Dev HUD + Sound Effects for Claude Code${NC}     ${RED}║${NC}"
echo -e "${RED}  ║${NC}  ${YELLOW}\"Kirov reporting...\"${NC}                        ${RED}║${NC}"
echo -e "${RED}  ╚══════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------
#  Prerequisites
# -----------------------------------------------------------
info "Checking prerequisites..."

check_dep git
check_dep tmux
check_dep python3

# Check for Claude Code
if ! command -v claude &>/dev/null; then
    warn "Claude Code CLI not found. Sounds + hooks will be installed but won't activate until you install Claude Code."
fi

# Check for audio player
if [[ "$(uname)" == "Darwin" ]]; then
    check_dep afplay
else
    if ! command -v mpv &>/dev/null && ! command -v paplay &>/dev/null && ! command -v aplay &>/dev/null; then
        warn "No audio player found (mpv/paplay/aplay). Sounds won't play until you install one."
    fi
fi

success "Prerequisites OK"

# -----------------------------------------------------------
#  Step 1: Clone or update repo
# -----------------------------------------------------------
if [[ -d "$INSTALL_DIR" ]]; then
    info "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || {
        warn "Pull failed, reinstalling..."
        rm -rf "$INSTALL_DIR"
        git clone "$REPO_URL" "$INSTALL_DIR"
    }
else
    # If running from a local clone (not curl|bash), copy instead
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [[ -f "$SCRIPT_DIR/scripts/tmux-hud.sh" ]]; then
        info "Installing from local copy..."
        cp -r "$SCRIPT_DIR" "$INSTALL_DIR"
    else
        info "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
fi

success "Repository ready at $INSTALL_DIR"

# -----------------------------------------------------------
#  Step 2: Create config (preserve existing)
# -----------------------------------------------------------
info "Setting up config..."
mkdir -p "$HOME/.claude"

CONF_FILE="$HOME/.claude/vibe-command.conf"
if [[ -f "$CONF_FILE" ]]; then
    info "Config already exists, preserving your settings"
else
    cp "$INSTALL_DIR/config/vibe-command.conf.default" "$CONF_FILE"
    success "Created config at $CONF_FILE"
fi

# Read config values
SOUND_PACK=$(read_config "sound_pack" "ra2")
VISUAL_THEME=$(read_config "visual_theme" "flag")

info "Sound pack: $SOUND_PACK | Visual theme: $VISUAL_THEME"

# -----------------------------------------------------------
#  Step 3: Detect country + generate themed tmux.conf
# -----------------------------------------------------------
info "Detecting your country..."

source "$INSTALL_DIR/themes/flags.sh"
source "$INSTALL_DIR/scripts/flag-theme.sh"

COUNTRY=$(read_config "country" "")
if [[ -z "$COUNTRY" ]]; then
    COUNTRY=$(detect_country)
fi
COLORS=$(get_flag_colors "$COUNTRY")
read -r PRIMARY SECONDARY LIGHT ACCENT EMOJI <<< "$COLORS"

success "Detected: $EMOJI $COUNTRY (colours: $PRIMARY/$SECONDARY/$LIGHT/$ACCENT)"

# Generate tmux.conf (backup existing)
if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup.$(date +%s)"
    info "Backed up existing ~/.tmux.conf"
fi

bash "$INSTALL_DIR/scripts/flag-theme.sh" "$COUNTRY" --generate --style "$VISUAL_THEME"

success "Themed tmux.conf generated (style: $VISUAL_THEME)"

# -----------------------------------------------------------
#  Step 4: Copy sounds (into pack subdirectories)
# -----------------------------------------------------------
info "Installing sound effects..."

# Install each available pack
for pack_dir in "$INSTALL_DIR/sounds/"*/; do
    pack_name=$(basename "$pack_dir")
    mkdir -p "$HOME/.claude/sounds/$pack_name"
    for f in "$pack_dir"*.mp3 "$pack_dir"*.aiff; do
        [[ -f "$f" ]] && cp "$f" "$HOME/.claude/sounds/$pack_name/"
    done
done

# Count sounds in active pack
SOUND_COUNT=$(ls "$HOME/.claude/sounds/$SOUND_PACK/"*.mp3 "$HOME/.claude/sounds/$SOUND_PACK/"*.aiff 2>/dev/null | wc -l | tr -d ' ')
TOTAL_PACKS=$(ls -d "$HOME/.claude/sounds/"*/ 2>/dev/null | wc -l | tr -d ' ')
success "Installed $SOUND_COUNT sounds (active pack: $SOUND_PACK, $TOTAL_PACKS packs total)"

# -----------------------------------------------------------
#  Step 5: Install scripts
# -----------------------------------------------------------
info "Installing scripts..."

mkdir -p "$HOME/.claude/scripts"
mkdir -p "$HOME/.claude/hooks"
mkdir -p "$HOME/.claude/hud-cache"

cp "$INSTALL_DIR/scripts/tmux-hud.sh" "$HOME/.claude/scripts/tmux-hud.sh"
cp "$INSTALL_DIR/scripts/sound-hook.sh" "$HOME/.claude/hooks/sound-hook.sh"
cp "$INSTALL_DIR/scripts/claude-state.sh" "$HOME/.claude/hooks/claude-state.sh"
# Keep legacy ra2-sounds.sh for backward compatibility
cp "$INSTALL_DIR/scripts/ra2-sounds.sh" "$HOME/.claude/hooks/ra2-sounds.sh"

chmod +x "$HOME/.claude/scripts/tmux-hud.sh"
chmod +x "$HOME/.claude/hooks/sound-hook.sh"
chmod +x "$HOME/.claude/hooks/claude-state.sh"
chmod +x "$HOME/.claude/hooks/ra2-sounds.sh"

success "Scripts installed"

# -----------------------------------------------------------
#  Step 6: Merge hooks into Claude Code settings
# -----------------------------------------------------------
info "Configuring Claude Code hooks..."

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    # Non-destructive merge: only add hooks if not already present
    if grep -q "sound-hook.sh" "$SETTINGS_FILE"; then
        info "Hooks already configured (v2), skipping"
    elif grep -q "ra2-sounds.sh" "$SETTINGS_FILE"; then
        info "Upgrading hooks from v1 to v2..."
        # Backup settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"

        # Replace ra2-sounds.sh refs with sound-hook.sh and add new hooks
        python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
home = '$HOME'

# Remove old ra2-sounds.sh references
for event in ['PostToolUse', 'Stop', 'Notification']:
    if event in hooks:
        hooks[event] = [h for h in hooks[event]
                        if not any('ra2-sounds' in str(hook) for hook in h.get('hooks', []))]
        if not hooks[event]:
            del hooks[event]

# Add v2 hooks
# PreToolUse - state tracker
pre = hooks.setdefault('PreToolUse', [])
pre.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PreToolUse {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# PostToolUse - sound + state
post = hooks.setdefault('PostToolUse', [])
post.append({
    'matcher': 'TaskUpdate|Bash|Task',
    'hooks': [{'type': 'command', 'command': f'{home}/.claude/hooks/sound-hook.sh'}]
})
post.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PostToolUse {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# PostToolUseFailure - state tracker
fail = hooks.setdefault('PostToolUseFailure', [])
fail.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PostToolUseFailure {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# Stop - sound + state
stop = hooks.setdefault('Stop', [])
stop.append({
    'matcher': '',
    'hooks': [
        {'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Stop {home}/.claude/hooks/sound-hook.sh <<< \"{{}}\"'},
        {'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Stop {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}
    ]
})

# Notification - sound
notif = hooks.setdefault('Notification', [])
notif.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Notification {home}/.claude/hooks/sound-hook.sh <<< \"{{}}\"'}]
})

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
" 2>/dev/null && success "Hooks upgraded to v2" || warn "Could not upgrade hooks. Add them manually from config/hooks.json.template"
    else
        # Backup settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"

        # Fresh install of v2 hooks
        python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
home = '$HOME'

# PreToolUse - state tracker
pre = hooks.setdefault('PreToolUse', [])
pre.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PreToolUse {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# PostToolUse - sound + state
post = hooks.setdefault('PostToolUse', [])
post.append({
    'matcher': 'TaskUpdate|Bash|Task',
    'hooks': [{'type': 'command', 'command': f'{home}/.claude/hooks/sound-hook.sh'}]
})
post.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PostToolUse {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# PostToolUseFailure - state tracker
fail = hooks.setdefault('PostToolUseFailure', [])
fail.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=PostToolUseFailure {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}]
})

# Stop - sound + state
stop = hooks.setdefault('Stop', [])
stop.append({
    'matcher': '',
    'hooks': [
        {'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Stop {home}/.claude/hooks/sound-hook.sh <<< \"{{}}\"'},
        {'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Stop {home}/.claude/hooks/claude-state.sh <<< \"{{}}\"', 'async': True}
    ]
})

# Notification - sound
notif = hooks.setdefault('Notification', [])
notif.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Notification {home}/.claude/hooks/sound-hook.sh <<< \"{{}}\"'}]
})

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
" 2>/dev/null && success "Hooks merged into settings.json" || warn "Could not merge hooks. Add them manually from config/hooks.json.template"
    fi
else
    # Create new settings file from template
    sed "s|{{HOME}}|$HOME|g" "$INSTALL_DIR/config/hooks.json.template" > "$SETTINGS_FILE"
    success "Created settings.json with hooks"
fi

# -----------------------------------------------------------
#  Step 7: Add shell wrapper function
# -----------------------------------------------------------
info "Setting up shell wrapper..."

SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

WRAPPER_MARKER="# vibe-command: startup sound"
WRAPPER_FUNC="
$WRAPPER_MARKER
claude() {
  local pack
  pack=\$(grep '^sound_pack=' ~/.claude/vibe-command.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
  pack=\"\${pack:-ra2}\"
  local startup
  case \"\$pack\" in
    homm3) startup=\"town_screen\" ;;
    *)     startup=\"battle_control_online\" ;;
  esac
  local snd=\"\$HOME/.claude/sounds/\$pack/\${startup}.mp3\"
  if [[ -f \"\$snd\" ]]; then
    if [[ \"\$(uname)\" == \"Darwin\" ]]; then
      afplay \"\$snd\" &
    elif command -v mpv &>/dev/null; then
      mpv --no-terminal \"\$snd\" &
    fi
  fi
  command claude \"\$@\"
}
"

# Remove old v1 wrapper marker if present
OLD_MARKER="# vibe-command: RA2 startup sound"

if [[ -n "$SHELL_RC" ]]; then
    # Remove old v1 wrapper if present
    if grep -q "$OLD_MARKER" "$SHELL_RC"; then
        python3 -c "
lines = open('$SHELL_RC').readlines()
out = []
skip = False
for line in lines:
    if '# vibe-command: RA2 startup sound' in line:
        skip = True
        continue
    if skip and line.strip() == '}':
        skip = False
        continue
    if not skip:
        out.append(line)
open('$SHELL_RC', 'w').writelines(out)
" 2>/dev/null
        info "Removed old v1 wrapper"
    fi

    if grep -q "$WRAPPER_MARKER" "$SHELL_RC"; then
        info "Shell wrapper already installed (v2)"
    else
        echo "$WRAPPER_FUNC" >> "$SHELL_RC"
        success "Added claude() wrapper to $(basename "$SHELL_RC")"
    fi
else
    warn "No .zshrc or .bashrc found. Add the claude() wrapper manually."
fi

# -----------------------------------------------------------
#  Step 8: Reload tmux if running
# -----------------------------------------------------------
if tmux list-sessions &>/dev/null; then
    tmux source-file "$HOME/.tmux.conf" 2>/dev/null && \
        success "Reloaded tmux config" || \
        info "Reload tmux manually: tmux source-file ~/.tmux.conf"
else
    info "Start tmux to see your HUD: tmux new -s dev"
fi

# -----------------------------------------------------------
#  Done!
# -----------------------------------------------------------
echo ""
echo -e "${RED}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}  ║${NC}  ${GREEN}${BOLD}INSTALLATION COMPLETE${NC}                       ${RED}║${NC}"
echo -e "${RED}  ║${NC}                                              ${RED}║${NC}"
echo -e "${RED}  ║${NC}  Country: ${BOLD}$EMOJI $COUNTRY${NC}                             ${RED}║${NC}"
echo -e "${RED}  ║${NC}  Sounds:  ${BOLD}$SOUND_COUNT files ($SOUND_PACK)${NC}                     ${RED}║${NC}"
echo -e "${RED}  ║${NC}  Theme:   ${BOLD}$VISUAL_THEME${NC}                              ${RED}║${NC}"
echo -e "${RED}  ║${NC}  Colors:  ${BOLD}$PRIMARY/$SECONDARY/$LIGHT/$ACCENT${NC}                     ${RED}║${NC}"
echo -e "${RED}  ║${NC}                                              ${RED}║${NC}"
echo -e "${RED}  ║${NC}  ${CYAN}\"Battle control online.\"${NC}                    ${RED}║${NC}"
echo -e "${RED}  ╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  ${CYAN}1.${NC} Open a new terminal (or source your shell RC)"
echo -e "  ${CYAN}2.${NC} Run ${BOLD}tmux new -s dev${NC} to see the HUD"
echo -e "  ${CYAN}3.${NC} Run ${BOLD}claude${NC} and hear the startup sound"
echo ""
echo -e "  ${BOLD}Switch theme:${NC}"
echo -e "    bash $INSTALL_DIR/scripts/flag-theme.sh --style matrix --generate"
echo -e "    bash $INSTALL_DIR/scripts/flag-theme.sh US --style scifi --generate"
echo ""
echo -e "  ${BOLD}Switch sound pack:${NC}"
echo -e "    Edit ~/.claude/vibe-command.conf → sound_pack=homm3"
echo ""
echo -e "  ${BOLD}Uninstall:${NC}    bash $INSTALL_DIR/uninstall.sh"
echo ""
