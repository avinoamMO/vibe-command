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

# -----------------------------------------------------------
#  Banner
# -----------------------------------------------------------
echo ""
echo -e "${RED}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}  ║${NC}  ${BOLD}VIBE-COMMAND${NC}                               ${RED}║${NC}"
echo -e "${RED}  ║${NC}  ${CYAN}Red Alert 2 Dev HUD for Claude Code${NC}        ${RED}║${NC}"
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
#  Step 2: Detect country + generate themed tmux.conf
# -----------------------------------------------------------
info "Detecting your country..."

source "$INSTALL_DIR/themes/flags.sh"
source "$INSTALL_DIR/scripts/flag-theme.sh"

COUNTRY=$(detect_country)
COLORS=$(get_flag_colors "$COUNTRY")
read -r PRIMARY SECONDARY LIGHT ACCENT EMOJI <<< "$COLORS"

success "Detected: $EMOJI $COUNTRY (colours: $PRIMARY/$SECONDARY/$LIGHT/$ACCENT)"

# Generate tmux.conf (backup existing)
if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup.$(date +%s)"
    info "Backed up existing ~/.tmux.conf"
fi

bash "$INSTALL_DIR/scripts/flag-theme.sh" "$COUNTRY" --generate

success "Themed tmux.conf generated"

# -----------------------------------------------------------
#  Step 3: Copy sounds
# -----------------------------------------------------------
info "Installing sound effects..."
mkdir -p "$HOME/.claude/sounds"

# Copy all sound files
for f in "$INSTALL_DIR/sounds/"*.mp3 "$INSTALL_DIR/sounds/"*.aiff; do
    [[ -f "$f" ]] && cp "$f" "$HOME/.claude/sounds/"
done

SOUND_COUNT=$(ls "$HOME/.claude/sounds/"*.mp3 "$HOME/.claude/sounds/"*.aiff 2>/dev/null | wc -l | tr -d ' ')
success "Installed $SOUND_COUNT sound files"

# -----------------------------------------------------------
#  Step 4: Install scripts
# -----------------------------------------------------------
info "Installing scripts..."

mkdir -p "$HOME/.claude/scripts"
mkdir -p "$HOME/.claude/hooks"

cp "$INSTALL_DIR/scripts/tmux-hud.sh" "$HOME/.claude/scripts/tmux-hud.sh"
cp "$INSTALL_DIR/scripts/ra2-sounds.sh" "$HOME/.claude/hooks/ra2-sounds.sh"

chmod +x "$HOME/.claude/scripts/tmux-hud.sh"
chmod +x "$HOME/.claude/hooks/ra2-sounds.sh"

success "Scripts installed"

# -----------------------------------------------------------
#  Step 5: Merge hooks into Claude Code settings
# -----------------------------------------------------------
info "Configuring Claude Code hooks..."

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    # Non-destructive merge: only add hooks if not already present
    if grep -q "ra2-sounds.sh" "$SETTINGS_FILE"; then
        info "Hooks already configured, skipping"
    else
        # Backup settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup.$(date +%s)"

        # Use python3 to merge hooks safely
        python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

home = '$HOME'

# PostToolUse
post = hooks.setdefault('PostToolUse', [])
post.append({
    'matcher': 'TaskUpdate|Bash|Task',
    'hooks': [{'type': 'command', 'command': f'{home}/.claude/hooks/ra2-sounds.sh'}]
})

# Stop
stop = hooks.setdefault('Stop', [])
stop.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Stop {home}/.claude/hooks/ra2-sounds.sh <<< \"{{}}\"'}]
})

# Notification
notif = hooks.setdefault('Notification', [])
notif.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': f'CLAUDE_HOOK_EVENT=Notification {home}/.claude/hooks/ra2-sounds.sh <<< \"{{}}\"'}]
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
#  Step 6: Add shell wrapper function
# -----------------------------------------------------------
info "Setting up shell wrapper..."

SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

WRAPPER_MARKER="# vibe-command: RA2 startup sound"
WRAPPER_FUNC="
$WRAPPER_MARKER
claude() {
  if [[ \"\$(uname)\" == \"Darwin\" ]]; then
    afplay ~/.claude/sounds/battle_control_online.mp3 &
  elif command -v mpv &>/dev/null; then
    mpv --no-terminal ~/.claude/sounds/battle_control_online.mp3 &
  fi
  command claude \"\$@\"
}
"

if [[ -n "$SHELL_RC" ]]; then
    if grep -q "$WRAPPER_MARKER" "$SHELL_RC"; then
        info "Shell wrapper already installed"
    else
        echo "$WRAPPER_FUNC" >> "$SHELL_RC"
        success "Added claude() wrapper to $(basename "$SHELL_RC")"
    fi
else
    warn "No .zshrc or .bashrc found. Add the claude() wrapper manually."
fi

# -----------------------------------------------------------
#  Step 7: Reload tmux if running
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
echo -e "${RED}  ║${NC}  Sounds:  ${BOLD}$SOUND_COUNT files${NC}                          ${RED}║${NC}"
echo -e "${RED}  ║${NC}  Theme:   ${BOLD}colour$PRIMARY / colour$SECONDARY / colour$LIGHT / colour$ACCENT${NC}  ${RED}║${NC}"
echo -e "${RED}  ║${NC}                                              ${RED}║${NC}"
echo -e "${RED}  ║${NC}  ${CYAN}\"Battle control online.\"${NC}                    ${RED}║${NC}"
echo -e "${RED}  ╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  ${CYAN}1.${NC} Open a new terminal (or source your shell RC)"
echo -e "  ${CYAN}2.${NC} Run ${BOLD}tmux new -s dev${NC} to see the HUD"
echo -e "  ${CYAN}3.${NC} Run ${BOLD}claude${NC} and hear \"Battle control online\""
echo ""
echo -e "  ${BOLD}Switch theme:${NC} bash $INSTALL_DIR/scripts/flag-theme.sh US --generate"
echo -e "  ${BOLD}Uninstall:${NC}    bash $INSTALL_DIR/uninstall.sh"
echo ""
