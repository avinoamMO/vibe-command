# Changelog

All notable changes to vibe-command are documented here.

## [2.0.0] - 2026-02-09

### Added
- Multi-pack sound system with abstract event mapping
- Heroes of Might and Magic III sound pack (14 sounds)
- Matrix visual theme (green on black, digital rain aesthetic)
- Sci-Fi visual theme (angular separators, command center feel)
- Context window % metric (current session token usage vs 200k)
- Git sync metric (ahead/behind remote tracking)
- Claude agent state circle (working/waiting/error/idle)
- Powerline glyph support (Nerd Font separators)
- Configuration file system (`~/.claude/vibe-command.conf`)
- Sound maps abstraction layer (`config/sound-maps.sh`)
- Template-based tmux config generation for all themes
- Test suite with 15+ tests
- CI/CD workflows (test on push, release on tag)
- GitHub Pages landing site
- Comprehensive README with troubleshooting guide

### Changed
- Sound hook upgraded from single-pack to multi-pack architecture
- Installer now supports v1-to-v2 upgrade path
- HUD script restructured with TTL-based caching per metric
- Flag theme generator now supports `--style` parameter

### Fixed
- Shell wrapper now reads active sound pack from config
- Hooks merge is non-destructive (preserves existing settings.json entries)

## [1.0.0] - 2026-02-09

### Added
- Initial release
- Red Alert 2 sound effects for Claude Code (21 sounds)
- tmux Dev HUD with 6 metrics (work time, tokens, agents, commits, branch, status)
- Auto flag theme detection for 50+ countries
- One-command installer via curl
- Uninstaller with tmux.conf backup restore
- Shell wrapper function for startup sound
- Claude Code hooks integration (PostToolUse, Stop, Notification)
