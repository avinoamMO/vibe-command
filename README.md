<p align="center">
  <br>
  <code>
  ╔══════════════════════════════════════════════════╗
  ║  VIBE-COMMAND                                   ║
  ║  Dev HUD + Sound Effects for Claude Code        ║
  ║  "Battle control online."                       ║
  ╚══════════════════════════════════════════════════╝
  </code>
  <br><br>
  <strong>Turn your Claude Code terminal into a command center.</strong>
  <br>
  Sound effects on every tool call. Real-time tmux HUD. Flag-themed colors.
  <br><br>
  <a href="https://github.com/avinoamMO/vibe-command/actions/workflows/test.yml"><img src="https://github.com/avinoamMO/vibe-command/actions/workflows/test.yml/badge.svg" alt="Tests"></a>
  <a href="https://github.com/avinoamMO/vibe-command/releases"><img src="https://img.shields.io/github/v/release/avinoamMO/vibe-command?style=flat-square&color=red" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/avinoamMO/vibe-command?style=flat-square" alt="License: MIT"></a>
  <a href="https://github.com/avinoamMO/vibe-command/stargazers"><img src="https://img.shields.io/github/stars/avinoamMO/vibe-command?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/tests-117%20passing-brightgreen?style=flat-square" alt="Tests: 117 passing" />
  <a href="#"><img src="https://img.shields.io/badge/shell-bash-green?style=flat-square" alt="Shell: Bash"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square" alt="Platform"></a>
</p>

---

## What is this?

**vibe-command** gamifies your AI coding workflow. It hooks into [Claude Code](https://docs.anthropic.com/en/docs/claude-code) events and plays sound effects from classic games while showing a real-time developer HUD in your tmux status bar.

Every git commit triggers a voice line. Every subagent spawn gets an alert. Your status bar shows context window usage, active agents, token consumption, and git status -- all themed to your country's flag colors.

It is dumb. It is perfect.

```
  dev  3.2h | main [+2~1 ^3v2] ──── ● ctx:85% | 142k tok | 2 agt | 7 commits | 14:32
```

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/avinoamMO/vibe-command/main/install.sh | bash
```

That's it. Open tmux and run `claude`.

---

## Features

- **Sound Effects** -- 12 event types mapped to classic game audio
- **Real-Time HUD** -- 9 metrics in your tmux status bar with TTL caching
- **2 Sound Packs** -- Red Alert 2 and Heroes of Might and Magic III
- **3 Visual Themes** -- Flag (country colors), Matrix (green on black), Sci-Fi (command center)
- **50+ Countries** -- Auto-detects your locale for flag-colored theming
- **Powerline Support** -- Optional Nerd Font glyphs for separators
- **Zero Slowdown** -- All metrics cached (10s-60s TTLs), HUD never blocks your terminal
- **One-Command Install** -- curl pipe bash, handles everything
- **Claude Code Hooks** -- Native integration via PreToolUse/PostToolUse/Stop events

---

## Sound Packs

### Red Alert 2 (default)

Command & Conquer: Red Alert 2 by Westwood Studios. 21 sound files.

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

### Heroes of Might and Magic III

Heroes III by New World Computing. 14 sound files.

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

Switch packs anytime -- edit `~/.claude/vibe-command.conf`:
```ini
sound_pack=homm3
```

---

## HUD Demo

The tmux status bar displays 9 real-time metrics:

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ dev  3.2h | main [+2~1 ^3v2] ──── ● ctx:85% | 142k tok | 2 agt | 7 commits | 14:32 │
  └─────────────────────────────────────────────────────────────────────────┘
    ▲    ▲      ▲     ▲    ▲          ▲   ▲        ▲       ▲       ▲          ▲
    │    │      │     │    │          │   │        │       │       │          │
  session │    branch │  sync      state │      tokens  agents  commits    clock
       worktime    status          context%
```

**Left side:**
- **Session name** -- tmux session, colored with flag primary/secondary
- **Work time** -- Active coding hours today (gap-aware -- AFK time excluded)
- **Git branch** -- Current branch name
- **Git status** -- Staged (+N) / unstaged (~M) / untracked (?U)
- **Git sync** -- Commits ahead (^N) / behind remote (vN)

**Right side:**
- **Status circle** -- Agent state: green (working), yellow (waiting), red (error), grey (idle)
- **Context %** -- Current session's context window usage (of 200k tokens)
- **Tokens** -- Output tokens consumed today across all sessions
- **Agents** -- Currently active subagents
- **Commits** -- Commits today in the current repo
- **Clock** -- 24h time

All metrics use file-based caching with TTLs (10s-60s) so the HUD never slows your terminal.

| Metric | Cache TTL | Source |
|--------|-----------|--------|
| Work time | 60s | `~/.claude/history.jsonl` (gap-aware sum) |
| Tokens | 60s | `~/.claude/projects/*/*.jsonl` (output_tokens) |
| Active agents | 10s | Subagent files modified <2min |
| Commits today | 30s | `git log --since=midnight` |
| Context % | 30s | Latest session JSONL input tokens / 200k |
| Git sync | 30s | `git rev-list` ahead/behind counts |
| Git branch | realtime | `git symbolic-ref` |
| Git status | realtime | `git diff` counts |
| Agent state | realtime | `~/.claude/hud-cache/claude-state` file age |

Test any metric directly:
```bash
~/.claude/scripts/tmux-hud.sh worktime    # "3.2h"
~/.claude/scripts/tmux-hud.sh context_pct # "85%"
~/.claude/scripts/tmux-hud.sh all         # all metrics
```

---

## Visual Themes

Three visual styles, all with the same HUD metrics:

### Flag (default)

Your country's flag colors applied to the status bar:
```
 dev  3.2h | main [ok] ──── ● ctx:42% | 89k tok | 0 agt | 3 commits | 16:45
```

### Matrix

Green on black, digital rain aesthetic:
```
 dev  3.2h | main [ok] ──── ● ctx:42% | 89k tok | 0 agt | 3 commits | 16:45
```

### Sci-Fi

Angular separators, command center feel with country colors:
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
```ini
visual_theme=matrix
```

---

## Auto Flag Detection

The installer detects your country from system locale and themes the entire HUD. 50+ countries supported:

| Region | Countries |
|--------|-----------|
| Middle East | Israel, UAE, Saudi Arabia, Turkey, Egypt |
| Americas | USA, Canada, Brazil, Mexico, Argentina, Colombia, Chile, Peru |
| Europe | Germany, UK, France, Italy, Spain, Netherlands, Poland, Ukraine, Sweden, Norway, Denmark, Finland, Switzerland, Austria, Belgium, Portugal, Czech Republic, Romania, Greece, Ireland |
| Asia Pacific | Japan, South Korea, China, India, Australia, New Zealand, Singapore, Taiwan, Thailand, Philippines, Vietnam, Indonesia, Malaysia |
| Africa | South Africa, Nigeria, Kenya, Ethiopia |

Switch country anytime:
```bash
bash ~/.vibe-command/scripts/flag-theme.sh JP --generate
tmux source-file ~/.tmux.conf
```

---

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/avinoamMO/vibe-command/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/avinoamMO/vibe-command.git
cd vibe-command && bash install.sh
```

### What the installer does

1. Checks prerequisites (git, tmux, python3, audio player)
2. Clones repo to `~/.vibe-command/`
3. Creates config at `~/.claude/vibe-command.conf`
4. Detects your country and generates themed `~/.tmux.conf`
5. Copies sounds to `~/.claude/sounds/{ra2,homm3}/`
6. Installs scripts to `~/.claude/scripts/` and `~/.claude/hooks/`
7. Merges hooks into `~/.claude/settings.json` (non-destructive)
8. Adds `claude()` shell wrapper for startup sound
9. Reloads tmux if running

### Requirements

- **macOS** or **Linux**
- **tmux** (any recent version)
- **python3** (for HUD metrics + JSON parsing)
- **Claude Code** CLI (sounds need hook events)
- **Audio player**: `afplay` (macOS, built-in) or `mpv`/`paplay`/`aplay` (Linux)
- **Nerd Font** (optional, for powerline glyphs)

### Upgrading from v1

Just re-run the installer:
```bash
bash ~/.vibe-command/install.sh
```

It preserves your config and upgrades hooks from v1 to v2 automatically.

---

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

### Powerline Glyphs

If you have a [Nerd Font](https://www.nerdfonts.com/) installed, enable powerline separators:
```ini
powerline_glyphs=true
```

This replaces ASCII separators with unicode glyphs for a cleaner look.

---

## How It Works

**Sounds** use [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) -- shell commands that fire on tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `Notification`). The sound hook reads event JSON from stdin and maps it to the right sound file via abstract event names resolved through the active pack.

**HUD** is a bash script called by tmux's `status-left` and `status-right` every 5 seconds. Each metric is cached to a file with a TTL (10s-60s) so it stays fast.

**Status Circle** uses a separate hook (`claude-state.sh`) that writes the current agent state (working/waiting/error) to a cache file on every tool event. The HUD reads this file and checks its age -- if >5 minutes old, it shows idle (grey).

**Themes** are tmux colour256 values mapped to country codes. The installer detects your country from system locale (macOS: `AppleLocale`, Linux: `$LANG` / timezone) and generates `~/.tmux.conf` from a template. Three template styles available (flag, matrix, scifi).

---

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
│   ├── sound-maps.sh               # Event-to-filename mapping per pack
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
├── tests/                          # Test suite
├── docs/                           # GitHub Pages site
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Troubleshooting

### No sound on macOS
Make sure your volume is not muted. `afplay` is built into macOS and should work out of the box. Test manually:
```bash
afplay ~/.claude/sounds/ra2/battle_control_online.mp3
```

### No sound on Linux
Install an audio player: `sudo apt install mpv` or `sudo apt install pulseaudio-utils` (for `paplay`).

### HUD not showing
1. Make sure tmux is running: `tmux new -s dev`
2. Reload config: `tmux source-file ~/.tmux.conf`
3. Check that scripts exist: `ls ~/.claude/scripts/tmux-hud.sh`

### Sounds not triggering on Claude Code events
1. Check hooks are configured: `cat ~/.claude/settings.json | grep sound-hook`
2. Verify the hook script exists: `ls ~/.claude/hooks/sound-hook.sh`
3. Test the hook manually: `echo '{}' | ~/.claude/hooks/sound-hook.sh`

### Wrong country detected
Set it explicitly in config:
```ini
# ~/.claude/vibe-command.conf
country=US
```
Then regenerate: `bash ~/.vibe-command/scripts/flag-theme.sh --generate && tmux source-file ~/.tmux.conf`

### Context % shows "?"
This means no active Claude Code session was found. Start a Claude Code session and the metric will populate.

### HUD shows stale data
Clear the cache: `rm -rf ~/.claude/hud-cache/*`

---

## Uninstall

```bash
bash ~/.vibe-command/uninstall.sh
```

Removes sounds, scripts, hooks, config, shell wrapper, and the install directory. Offers to restore your pre-install tmux.conf from backup.

---

## Sound Disclaimers

**Red Alert 2**: Sound effects from Command & Conquer: Red Alert 2 by Westwood Studios / Electronic Arts. See [sounds/ra2/DISCLAIMER.md](sounds/ra2/DISCLAIMER.md).

**Heroes of Might and Magic III**: Sound effects from Heroes of Might and Magic III by New World Computing / Ubisoft. See [sounds/homm3/DISCLAIMER.md](sounds/homm3/DISCLAIMER.md).

All sounds included for personal, non-commercial use only.

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Ideas for contributions:
- New sound packs (StarCraft, Age of Empires, Civilization, etc.)
- New visual themes
- Additional country flag colors
- Linux audio player improvements
- New HUD metrics

---

## License

[MIT](LICENSE)

---

<p align="center">
  <em>"Kirov reporting..."</em>
  <br><br>
  Built by <a href="https://github.com/avinoamMO">Avinoam Oltchik</a>
</p>
