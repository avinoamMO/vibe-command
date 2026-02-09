# vibe-command

**Red Alert 2 Dev HUD for Claude Code**

Turn your Claude Code terminal into a Red Alert 2 command center. Sound effects on every tool call. tmux HUD themed to your country's flag colors. One-command install.

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

Every Claude Code action triggers a Red Alert 2 sound:

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

### tmux Dev HUD

A status bar showing real-time dev metrics:

```
 dev  3.2h | main [+2~1] ────── 142k tok | 2 agt | 7 commits | 14:32
```

- **Work time**: Active coding hours today (gap-aware — AFK time doesn't count)
- **Git branch + status**: Current branch with staged/unstaged/untracked counts
- **Tokens**: Output tokens consumed today across all sessions
- **Agents**: Currently active subagents
- **Commits**: Commits today in the current repo
- **Clock**: 24h time

All metrics are cached with TTLs so the HUD never slows your terminal.

### Auto Flag Theme

The installer detects your country and themes the entire HUD in your flag colors.

50+ countries supported:

| Country | Colors |
|---------|--------|
| Israel | Blue / White / Light Blue / Gold |
| USA | Red / Navy / White / Red |
| Germany | Black / Red / Gold / Red |
| Ukraine | Blue / Yellow / Light Blue / Yellow |
| Japan | Red / White / Pink / Red |
| Brazil | Green / Yellow / Light Green / Blue |
| ... | [50+ more in themes/flags.sh] |

Switch theme anytime:

```bash
# Preview a theme
bash ~/.vibe-command/scripts/flag-theme.sh JP

# Apply a theme
bash ~/.vibe-command/scripts/flag-theme.sh JP --generate
tmux source-file ~/.tmux.conf
```

## How It Works

**Sounds** use [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — shell commands that fire on tool events (`PostToolUse`, `Stop`, `Notification`). The hook script reads the event JSON from stdin and maps it to the right RA2 sound file.

**HUD** is a bash script called by tmux's `status-left` and `status-right` every 5 seconds. Each metric is cached to a file with a TTL (10s-60s) so it stays fast.

**Themes** are tmux colour256 values mapped to country codes. The installer detects your country from system locale (macOS: `AppleLocale`, Linux: `$LANG` / timezone) and generates `~/.tmux.conf` from a template.

## File Layout

```
~/.claude/
├── sounds/               # RA2 MP3/AIFF files
├── scripts/
│   └── tmux-hud.sh       # HUD data provider
└── hooks/
    └── ra2-sounds.sh     # Sound effect hook

~/.tmux.conf              # Generated themed config
~/.vibe-command/          # Install directory (this repo)
```

## Requirements

- **macOS** or **Linux**
- **tmux** (any recent version)
- **python3** (for HUD metrics + JSON parsing)
- **Claude Code** CLI (sounds play without it, but hooks need it)
- **Audio player**: `afplay` (macOS, built-in) or `mpv`/`paplay`/`aplay` (Linux)

## Uninstall

```bash
bash ~/.vibe-command/uninstall.sh
```

Removes sounds, scripts, hooks, shell wrapper, and the install directory. Offers to restore your pre-install tmux.conf from backup.

## Sound Disclaimer

Sound effects are from Command & Conquer: Red Alert 2 by Westwood Studios / Electronic Arts. Included for personal, non-commercial use. See [sounds/DISCLAIMER.md](sounds/DISCLAIMER.md).

## License

MIT. See [LICENSE](LICENSE).

---

*"Kirov reporting..."*
