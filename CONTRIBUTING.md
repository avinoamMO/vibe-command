# Contributing to vibe-command

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/vibe-command.git`
3. Create a branch: `git checkout -b feature/my-feature`
4. Make your changes
5. Run the test suite: `bash tests/run-tests.sh`
6. Commit with a clear message: `git commit -m "Add: new feature description"`
7. Push to your fork: `git push origin feature/my-feature`
8. Open a Pull Request

## Commit Message Convention

```
Add: new feature description
Fix: bug description
Update: enhancement to existing feature
Remove: removed feature or file
Docs: documentation changes
Test: test additions or changes
CI: CI/CD changes
```

## Code Guidelines

### Shell Scripts

- Use `#!/usr/bin/env bash` as the shebang
- Add `set -euo pipefail` for safety (in main scripts, not libraries)
- Use `shellcheck` to lint your scripts before submitting
- Add header comments to every script explaining its purpose
- Use functions to organize code
- Be compatible with bash 3.2+ (no associative arrays -- macOS ships with bash 3.2)
- Quote all variable expansions: `"$var"` not `$var`

### Adding a Sound Pack

1. Create a new directory under `sounds/your-pack-name/`
2. Add sound files (MP3 preferred, AIFF also supported)
3. Add a `DISCLAIMER.md` in the sound directory with source attribution
4. Add the event-to-filename mapping in `config/sound-maps.sh`:
   ```bash
   _yourpack_map() {
       local event="$1"
       case "$event" in
           startup)        echo "your_startup_sound" ;;
           task_complete)  echo "your_complete_sound" ;;
           # ... map all events
       esac
   }
   ```
5. Add the pack to the `get_sound()` function's case statement
6. Update `README.md` with the new pack's sound table

### Adding a Visual Theme

1. Create a new template at `config/tmux-THEMENAME.conf.template`
2. Use the placeholders: `{{PRIMARY}}`, `{{SECONDARY}}`, `{{LIGHT}}`, `{{ACCENT}}`, `{{DIV}}`
3. Add the style name to `scripts/flag-theme.sh`'s template selector
4. Update `README.md` with the new theme

### Adding Country Flag Colors

1. Edit `themes/flags.sh`
2. Add a new case in `get_flag_colors()` with 4 colour256 values + emoji
3. If adding timezone detection, update `scripts/flag-theme.sh`'s `detect_country()` function

## Testing

Run the test suite before submitting:

```bash
bash tests/run-tests.sh
```

If you're adding a new feature, please include tests for it.

## What We're Looking For

- New sound packs from classic games
- New visual themes
- Additional country flag colors
- Linux compatibility improvements
- New HUD metrics (must be lightweight with TTL caching)
- Bug fixes
- Documentation improvements

## What to Avoid

- Breaking changes to existing config format
- Dependencies beyond the basic requirements (bash, python3, tmux, git)
- Sound files that aren't properly attributed
- Changes that slow down the HUD (all metrics must be cached)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
