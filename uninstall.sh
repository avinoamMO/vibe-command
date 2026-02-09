#!/usr/bin/env bash
# =============================================================
#  vibe-command uninstaller — clean removal
# =============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.vibe-command"

info()    { echo -e "${CYAN}[vibe-command]${NC} $*"; }
success() { echo -e "${GREEN}[vibe-command]${NC} $*"; }
warn()    { echo -e "${YELLOW}[vibe-command]${NC} $*"; }

echo ""
echo -e "${RED}  vibe-command uninstaller${NC}"
echo ""

# -----------------------------------------------------------
#  Remove shell wrapper (both v1 and v2 markers)
# -----------------------------------------------------------
info "Removing shell wrapper..."

for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rcfile" ]] && grep -q "# vibe-command:" "$rcfile"; then
        # Remove the wrapper block (from marker to closing brace)
        python3 -c "
lines = open('$rcfile').readlines()
out = []
skip = False
for line in lines:
    if '# vibe-command:' in line:
        skip = True
        continue
    if skip and line.strip() == '}':
        skip = False
        continue
    if not skip:
        out.append(line)
open('$rcfile', 'w').writelines(out)
" 2>/dev/null && success "Removed wrapper from $(basename "$rcfile")" || warn "Could not auto-remove wrapper from $(basename "$rcfile")"
    fi
done

# -----------------------------------------------------------
#  Remove hooks from settings.json
# -----------------------------------------------------------
info "Removing hooks from Claude Code settings..."

SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]] && (grep -q "sound-hook.sh\|ra2-sounds.sh\|claude-state.sh" "$SETTINGS_FILE"); then
    python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

for event in list(hooks.keys()):
    hooks[event] = [h for h in hooks[event]
                    if not any(any(kw in str(hook) for kw in ['sound-hook', 'ra2-sounds', 'claude-state'])
                              for hook in h.get('hooks', []))]
    if not hooks[event]:
        del hooks[event]

if not hooks:
    if 'hooks' in settings:
        del settings['hooks']

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
" 2>/dev/null && success "Removed hooks from settings.json" || warn "Could not auto-remove hooks. Edit ~/.claude/settings.json manually."
fi

# -----------------------------------------------------------
#  Remove installed files
# -----------------------------------------------------------
info "Removing scripts..."
rm -f "$HOME/.claude/scripts/tmux-hud.sh"
rm -f "$HOME/.claude/hooks/ra2-sounds.sh"
rm -f "$HOME/.claude/hooks/sound-hook.sh"
rm -f "$HOME/.claude/hooks/claude-state.sh"

info "Removing sounds..."
# Remove all sound pack directories
rm -rf "$HOME/.claude/sounds/ra2"
rm -rf "$HOME/.claude/sounds/homm3"

# Also clean up any legacy flat sounds (v1 installs)
for sound in acknowledged affirmative at_your_service battle_control_online \
    battle_control_terminated building construction_complete da for_mother_russia \
    insufficient_funds kirov_reporting mission_accomplished moving_out \
    new_construction_options reinforcements_have_arrived sir_yes_sir training \
    unable_to_comply unit_ready yes_commander; do
    rm -f "$HOME/.claude/sounds/${sound}.mp3" "$HOME/.claude/sounds/${sound}.aiff"
done

info "Removing config..."
rm -f "$HOME/.claude/vibe-command.conf"

# Clean up empty dirs
rmdir "$HOME/.claude/sounds" 2>/dev/null || true
rmdir "$HOME/.claude/hooks" 2>/dev/null || true
rmdir "$HOME/.claude/scripts" 2>/dev/null || true

# -----------------------------------------------------------
#  Restore tmux.conf
# -----------------------------------------------------------
info "Checking for tmux.conf backup..."
LATEST_BACKUP=$(ls -t "$HOME/.tmux.conf.backup."* 2>/dev/null | head -1)
if [[ -n "$LATEST_BACKUP" ]]; then
    echo -e "  Found backup: ${BOLD}$LATEST_BACKUP${NC}"
    read -rp "  Restore it? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        cp "$LATEST_BACKUP" "$HOME/.tmux.conf"
        success "Restored tmux.conf from backup"
    fi
else
    warn "No tmux.conf backup found. Your themed config remains at ~/.tmux.conf"
fi

# -----------------------------------------------------------
#  Remove install dir
# -----------------------------------------------------------
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    success "Removed $INSTALL_DIR"
fi

# Remove HUD cache
rm -rf "$HOME/.claude/hud-cache"

echo ""
success "vibe-command uninstalled. \"Battle control terminated.\""
echo ""
