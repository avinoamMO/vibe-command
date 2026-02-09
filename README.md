# vibe-command

**Dev HUD + Sound Effects for Claude Code**

Turn your Claude Code terminal into a command center. Sound effects on every tool call. tmux HUD with real-time metrics themed to your country's flag colors. Multiple sound packs and visual themes. One-command install.

```
"Battle control online."
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/avinoamMO/vibe-command/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/avinoamMO/vibe-command.git
cd vibe-command && bash install.sh
```

## What You Get

### Sound Effects

Every Claude Code action triggers a sound effect. Two packs included:

**Red Alert 2** (default):

| Event | Sound |
|-------|-------|
| Start Claude | "Battle control online" |
| Git commit | "Yes, Commander" / "Sir, yes sir" / "Da" |
| Git push | "Moving out" |
| Build succeeds | "Acknowledged" |
| Tests pass | "Affirmative" |
| Subagent spawns | "Kirov reporting" / "Training" / "Unit ready" |
| npm install | "Reinforcements have arrived" |
| Deploy | "Building..." |
| Task completed | "Construction complete" |
| Error / failure | "Unable to comply" |
| Session ends | "Mission accomplished" |
| Notification | "New construction options" |

**Heroes of Might and Magic III**:

| Event | Sound |
|-------|-------|
| Start Claude | Town Screen theme |
| Git commit | Cavalry Move |
| Git push | Ship Move |
| Build succeeds | Treasure |
| Tests pass | Positive Luck |
| Subagent spawns | Dragon Roar / Angel Summon / Phoenix Cast |
| npm install | Recruit |
| Deploy | Build |
| Task completed | Spell Cast |
| Error / failure | Negative Luck |
| Session ends | Victory fanfare |
| Notification | Quest Received |

### tmux Dev HUD

A status bar showing real-time dev metrics:

```
 dev  3.2h | main [+2~1 ^3v2] ──── ● ctx:85% | 142k tok | 2 agt | 7 commits | 14:32
```

**Left side:**
- **Session name**: tmux session (colored with flag primary/secondary)
- **Work time**: Active coding hours today (gap-aware — AFK time doesn't count)
- **Git branch**: Current branch name
- **Git status**: Staged (+N) / unstaged (~M) / untracked (?U)
- **Git sync**: Commits to push (^N) / behind remote (vN)

**Right side:**
- **Status circle**: Agent state — green (working), yellow (waiting), red (error), grey (idle)
- **Context %**: Current session's context window usage (out of 200k tokens)
- **Tokens**: Output tokens consumed today across all sessions
- **Agents**: Currently active subagents
- **Commits**: Commits today in the current repo
- **Clock**: 24h time

All metrics are cached with TTLs (10s-60s) so the HUD never slows your terminal.

### Visual Themes

Three visual styles, all with the same HUD metrics:

**Flag** (default) — Your country's flag colors:
```
 dev  3.2h | main [ok] ──── ● ctx:42% | 89k tok | 0 agt | 3 commits | 16:45
```

**Matrix** — Green on black, digital rain aesthetic:
```
 dev  3.2h | main [ok] ──── ● ctx:42% | 89k tok | 0 agt | 3 commits | 16:45
```

**Sci-Fi** — Angular separators, command center feel with country colors:
```
 dev  3.2h | main [ok] ──── ● ⚡42% | 89k tok | ◆0 agt | 3 commits | 16:45
```

Switch themes:

```bash
# Preview
bash ~/.vibe-command/scripts/flag-theme.sh --style matrix

# Apply
bash ~/.vibe-command/scripts/flag-theme.sh --style matrix --generate
tmux source-file ~/.tmux.conf

# Combine with country
bash ~/.vibe-command/scripts/flag-theme.sh US --style scifi --generate
```

Or set permanently in config:

```bash
# Edit ~/.claude/vibe-command.conf
visual_theme=matrix
```

### Powerline Glyphs

If you have a [Nerd Font](https://www.nerdfonts.com/) installed, enable powerline separators:

```bash
# Edit ~/.claude/vibe-command.conf
powerline_glyphs=true
```

This replaces ASCII separators (`|`, `>`, `<`) with unicode glyphs (`│`, ``, ``).

### Auto Flag Theme

The installer detects your country and themes the entire HUD in your flag colors. 50+ countries supported:

| Country | Colors |
|---------|--------|
| Israel | Blue / White / Light Blue / Gold |
| USA | Red / Navy / White / Red |
| Germany | Black / Red / Gold / Red |
| Ukraine | Blue / Yellow / Light Blue / Yellow |
| Japan | Red / White / Pink / Red |
| Brazil | Green / Yellow / Light Green / Blue |
| ... | [50+ more in themes/flags.sh] |

Switch country anytime:

```bash
bash ~/.vibe-command/scripts/flag-theme.sh JP --generate
tmux source-file ~/.tmux.conf
```

## Configuration

All settings in `~/.claude/vibe-command.conf`:

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `sound_pack` | `ra2`, `homm3` | `ra2` | Active sound pack |
| `visual_theme` | `flag`, `matrix`, `scifi` | `flag` | Visual theme style |
| `country` | 2-letter ISO code | *(auto-detect)* | Country for flag colors |
| `powerline_glyphs` | `true`, `false` | `false` | Use Nerd Font glyphs |

Example:

```ini
sound_pack=homm3
visual_theme=matrix
country=IL
powerline_glyphs=true
```

After editing, regenerate your tmux config:

```bash
bash ~/.vibe-command/scripts/flag-theme.sh --generate
tmux source-file ~/.tmux.conf
```

Sound pack changes take effect immediately (no restart needed).

## How It Works

**Sounds** use [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell commands that fire on tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `Notification`). The sound hook reads event JSON from stdin and maps it to the right sound file via abstract event names resolved through the active pack.

**HUD** is a bash script called by tmux's `status-left` and `status-right` every 5 seconds. Each metric is cached to a file with a TTL (10s-60s) so it stays fast.

**Status Circle** uses a separate hook (`claude-state.sh`) that writes the current agent state (working/waiting/error) to a cache file on every tool event. The HUD reads this file and checks its age — if >5 minutes old, it shows idle (grey).

**Themes** are tmux colour256 values mapped to country codes. The installer detects your country from system locale (macOS: `AppleLocale`, Linux: `$LANG` / timezone) and generates `~/.tmux.conf` from a template. Three template styles available (flag, matrix, scifi).

## File Layout

```
~/.claude/
├── vibe-command.conf     # User config (sound pack, theme, etc.)
├── sounds/
│   ├── ra2/              # Red Alert 2 MP3/AIFF files (21 sounds)
│   └── homm3/            # Heroes III MP3 files (14 sounds)
├── scripts/
│   └── tmux-hud.sh       # HUD data provider (9 metrics)
├── hooks/
│   ├── sound-hook.sh     # Multi-pack sound effect hook
│   └── claude-state.sh   # Agent state tracker hook
└── hud-cache/            # TTL-based metric cache files

~/.tmux.conf              # Generated themed config
~/.vibe-command/          # Install directory (this repo)
```

**Repository layout:**

```
vibe-command/
├── config/
│   ├── vibe-command.conf.default   # Default config template
│   ├── sound-maps.sh               # Event→filename mapping per pack
│   ├── hooks.json.template         # Claude Code hooks template
│   ├── tmux-flag.conf.template     # Flag visual theme
│   ├── tmux-matrix.conf.template   # Matrix visual theme
│   └── tmux-scifi.conf.template    # Sci-fi visual theme
├── scripts/
│   ├── tmux-hud.sh                 # HUD data provider
│   ├── flag-theme.sh               # Country detection + theme generator
│   ├── sound-hook.sh               # Multi-pack sound hook
│   ├── claude-state.sh             # Agent state tracker
│   └── ra2-sounds.sh               # Legacy v1 sound hook
├── themes/
│   └── flags.sh                    # 50+ country color mappings
├── sounds/
│   ├── ra2/                        # Red Alert 2 sound files
│   └── homm3/                      # Heroes III sound files
├── install.sh
├── uninstall.sh
└── README.md
```

## HUD Metrics Reference

| Metric | Component | Cache TTL | Source |
|--------|-----------|-----------|--------|
| Work time | `worktime` | 60s | `~/.claude/history.jsonl` (gap-aware sum) |
| Tokens | `tokens` | 60s | `~/.claude/projects/*/*.jsonl` (output_tokens) |
| Active agents | `agents` | 10s | Subagent files modified <2min |
| Commits today | `commits` | 30s | `git log --since=midnight` |
| Git branch | `branch` | — | `git symbolic-ref` |
| Git status | `status` | — | `git diff` counts |
| Context % | `context_pct` | 30s | Latest session JSONL input tokens / 200k |
| Git sync | `git_sync` | 30s | `git rev-list` ahead/behind counts |
| Agent state | `claude_state` | — | `~/.claude/hud-cache/claude-state` file age |

Test any metric directly:

```bash
~/.claude/scripts/tmux-hud.sh worktime    # → "3.2h"
~/.claude/scripts/tmux-hud.sh context_pct # → "85%"
~/.claude/scripts/tmux-hud.sh all         # → all metrics
```

## Requirements

- **macOS** or **Linux**
- **tmux** (any recent version)
- **python3** (for HUD metrics + JSON parsing)
- **Claude Code** CLI (sounds play without it, but hooks need it)
- **Audio player**: `afplay` (macOS, built-in) or `mpv`/`paplay`/`aplay` (Linux)
- **Nerd Font** (optional, for powerline glyphs)

## Upgrading from v1

If you installed vibe-command v1, just re-run the installer:

```bash
bash ~/.vibe-command/install.sh
```

The installer automatically:
- Preserves your existing config
- Upgrades hooks from ra2-sounds.sh to sound-hook.sh
- Replaces the old shell wrapper with the new multi-pack version
- Installs both sound packs (RA2 + HoMM3)

## Uninstall

```bash
bash ~/.vibe-command/uninstall.sh
```

Removes sounds, scripts, hooks, config, shell wrapper, and the install directory. Offers to restore your pre-install tmux.conf from backup.

## Sound Disclaimers

**Red Alert 2**: Sound effects from Command & Conquer: Red Alert 2 by Westwood Studios / Electronic Arts. See [sounds/ra2/DISCLAIMER.md](sounds/ra2/DISCLAIMER.md).

**Heroes of Might and Magic III**: Sound effects from Heroes of Might and Magic III by New World Computing / Ubisoft. See [sounds/homm3/DISCLAIMER.md](sounds/homm3/DISCLAIMER.md).

All sounds included for personal, non-commercial use only.

## License

MIT. See [LICENSE](LICENSE).

---

*"Kirov reporting..."*
