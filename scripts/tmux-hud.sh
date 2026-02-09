#!/usr/bin/env bash
# =============================================================
#  Dev HUD — tmux status bar data provider
#  Components: worktime, tokens, agents, commits, branch, status,
#              context_pct, git_sync, claude_state
#
#  Usage: tmux-hud.sh <component>
#  Called by tmux status-left / status-right every N seconds
# =============================================================

COMPONENT="${1:-all}"
CACHE_DIR="$HOME/.claude/hud-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null

# -----------------------------------------------------------
#  CACHING — expensive ops get a TTL-based file cache
# -----------------------------------------------------------
cached() {
    local key="$1" ttl="$2"
    local cache_file="$CACHE_DIR/$key"
    if [[ -f "$cache_file" ]]; then
        local now age mtime
        now=$(date +%s)
        if [[ "$(uname)" == "Darwin" ]]; then
            mtime=$(stat -f %m "$cache_file" 2>/dev/null)
        else
            mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
        fi
        age=$((now - mtime))
        if [[ $age -lt $ttl ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

write_cache() {
    local key="$1" value="$2"
    echo "$value" > "$CACHE_DIR/$key"
}

# -----------------------------------------------------------
#  HELPERS
# -----------------------------------------------------------
get_pane_cwd() {
    local cwd
    cwd=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    if [[ -n "$cwd" ]] && [[ -d "$cwd" ]]; then
        echo "$cwd"
        return
    fi
    echo "${PWD:-$HOME}"
}

# -----------------------------------------------------------
#  WORK TIME TODAY (active hours, gap detection)
#  Cache: 60s
# -----------------------------------------------------------
get_work_time() {
    local val
    if val=$(cached worktime 60); then
        echo "$val"
        return
    fi

    val=$(python3 -c "
import json, os
from datetime import datetime

today = datetime.now().strftime('%Y-%m-%d')
timestamps = []
path = os.path.expanduser('~/.claude/history.jsonl')
if not os.path.exists(path):
    print('0.0h')
    exit()
with open(path) as f:
    for line in f:
        try:
            d = json.loads(line)
            ts = d['timestamp'] / 1000
            if datetime.fromtimestamp(ts).strftime('%Y-%m-%d') == today:
                timestamps.append(ts)
        except:
            pass

if len(timestamps) < 2:
    print('0.0h')
    exit()

timestamps.sort()
active = 0
GAP = 30 * 60
for i in range(1, len(timestamps)):
    gap = timestamps[i] - timestamps[i-1]
    if gap < GAP:
        active += gap

print(f'{active/3600:.1f}h')
" 2>/dev/null)

    val="${val:-0.0h}"
    write_cache worktime "$val"
    echo "$val"
}

# -----------------------------------------------------------
#  OUTPUT TOKENS TODAY (from session JSONL files)
#  Cache: 60s
# -----------------------------------------------------------
get_tokens_today() {
    local val
    if val=$(cached tokens 60); then
        echo "$val"
        return
    fi

    val=$(python3 -c "
import json, os, glob
from datetime import datetime

today = datetime.now().strftime('%Y-%m-%d')

# Search all project dirs for session files
base = os.path.expanduser('~/.claude/projects')
total = 0

if os.path.isdir(base):
    for root, dirs, files in os.walk(base):
        for fname in files:
            if not fname.endswith('.jsonl'):
                continue
            fpath = os.path.join(root, fname)
            try:
                mtime = datetime.fromtimestamp(os.path.getmtime(fpath))
                if mtime.strftime('%Y-%m-%d') != today:
                    continue
                with open(fpath) as fh:
                    for line in fh:
                        if 'output_tokens' not in line:
                            continue
                        try:
                            d = json.loads(line)
                            u = d.get('usage') or (d.get('message') or {}).get('usage')
                            if u:
                                total += u.get('output_tokens', 0)
                        except:
                            pass
            except:
                pass

if total >= 1000000:
    print(f'{total/1000000:.1f}M')
elif total >= 1000:
    print(f'{total//1000}k')
else:
    print(str(total))
" 2>/dev/null)

    val="${val:-0}"
    write_cache tokens "$val"
    echo "$val"
}

# -----------------------------------------------------------
#  ACTIVE AGENTS (subagent files modified in last 2 min)
#  Cache: 10s
# -----------------------------------------------------------
get_active_agents() {
    local val
    if val=$(cached agents 10); then
        echo "$val"
        return
    fi

    local count=0
    local projects_dir="$HOME/.claude/projects"

    if [[ -d "$projects_dir" ]]; then
        # Find any subagent jsonl files modified in last 2 min across all projects
        count=$(find "$projects_dir" -path "*/subagents/*.jsonl" -mmin -2 2>/dev/null | wc -l | tr -d ' ')
    fi

    write_cache agents "$count"
    echo "$count"
}

# -----------------------------------------------------------
#  COMMITS TODAY (git log since midnight)
#  Cache: 30s
# -----------------------------------------------------------
get_commits_today() {
    local val
    if val=$(cached commits 30); then
        echo "$val"
        return
    fi

    local cwd
    cwd=$(get_pane_cwd)
    local count
    count=$(git -C "$cwd" log --since=midnight --oneline 2>/dev/null | wc -l | tr -d ' ')
    count="${count:-0}"

    write_cache commits "$count"
    echo "$count"
}

# -----------------------------------------------------------
#  GIT BRANCH
# -----------------------------------------------------------
get_git_branch() {
    local cwd
    cwd=$(get_pane_cwd)
    local branch
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [[ -z "$branch" ]]; then
        branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        [[ -n "$branch" ]] && echo "[$branch]" && return
    fi
    echo "${branch:-~}"
}

# -----------------------------------------------------------
#  GIT STATUS (staged/unstaged/untracked counts)
# -----------------------------------------------------------
get_git_status() {
    local cwd
    cwd=$(get_pane_cwd)
    if ! git -C "$cwd" rev-parse --git-dir &>/dev/null; then
        echo ""
        return
    fi
    local staged unstaged untracked
    staged=$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    unstaged=$(git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    local indicator=""
    [[ "$staged" -gt 0 ]] && indicator="${indicator}+${staged}"
    [[ "$unstaged" -gt 0 ]] && indicator="${indicator}~${unstaged}"
    [[ "$untracked" -gt 0 ]] && indicator="${indicator}?${untracked}"
    echo "${indicator:-ok}"
}

# -----------------------------------------------------------
#  CONTEXT WINDOW % (token usage of current session)
#  Cache: 30s
# -----------------------------------------------------------
get_context_pct() {
    local val
    if val=$(cached context_pct 30); then
        echo "$val"
        return
    fi

    val=$(python3 -c "
import json, os, glob

base = os.path.expanduser('~/.claude/projects')
if not os.path.isdir(base):
    print('0%')
    exit()

# Find most recent .jsonl that isn't in a subagents dir
candidates = []
for root, dirs, files in os.walk(base):
    # Skip subagent directories
    if '/subagents' in root or 'subagents' in os.path.basename(root):
        continue
    for f in files:
        if f.endswith('.jsonl'):
            fpath = os.path.join(root, f)
            candidates.append((os.path.getmtime(fpath), fpath))

if not candidates:
    print('?')
    exit()

candidates.sort(reverse=True)
latest = candidates[0][1]

# Read last usage block from the file (scan last 50 lines for speed)
lines = []
try:
    with open(latest, 'rb') as fh:
        # Seek to end and read last ~50KB
        fh.seek(0, 2)
        size = fh.tell()
        fh.seek(max(0, size - 50000))
        chunk = fh.read().decode('utf-8', errors='replace')
        lines = chunk.strip().split('\n')
except:
    print('?')
    exit()

# Find last line with usage data
total = 0
for line in reversed(lines):
    if 'input_tokens' not in line:
        continue
    try:
        d = json.loads(line)
        u = d.get('usage') or (d.get('message') or {}).get('usage')
        if u:
            total = u.get('input_tokens', 0)
            total += u.get('cache_creation_input_tokens', 0)
            total += u.get('cache_read_input_tokens', 0)
            break
    except:
        continue

if total == 0:
    print('0%')
else:
    pct = min(int(total * 100 / 200000), 100)
    print(f'{pct}%')
" 2>/dev/null)

    val="${val:-?}"
    write_cache context_pct "$val"
    echo "$val"
}

# -----------------------------------------------------------
#  GIT PUSH/SYNC STATUS (ahead/behind remote)
#  Cache: 30s
# -----------------------------------------------------------
get_git_sync() {
    local val
    if val=$(cached git_sync 30); then
        echo "$val"
        return
    fi

    local cwd
    cwd=$(get_pane_cwd)

    # Check if upstream is configured
    if ! git -C "$cwd" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
        write_cache git_sync ""
        echo ""
        return
    fi

    local ahead behind indicator=""
    ahead=$(git -C "$cwd" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    behind=$(git -C "$cwd" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)

    [[ "$ahead" -gt 0 ]] && indicator="^${ahead}"
    [[ "$behind" -gt 0 ]] && indicator="${indicator}v${behind}"

    write_cache git_sync "$indicator"
    echo "$indicator"
}

# -----------------------------------------------------------
#  CLAUDE STATE (status circle: working/waiting/error/idle)
#  No cache — reads state file directly (cheap)
# -----------------------------------------------------------
get_claude_state() {
    local state_file="$CACHE_DIR/claude-state"

    if [[ ! -f "$state_file" ]]; then
        # No state = idle (grey)
        echo "#[fg=colour240]●"
        return
    fi

    local state now mtime age
    state=$(cat "$state_file" 2>/dev/null)
    now=$(date +%s)
    if [[ "$(uname)" == "Darwin" ]]; then
        mtime=$(stat -f %m "$state_file" 2>/dev/null)
    else
        mtime=$(stat -c %Y "$state_file" 2>/dev/null)
    fi
    age=$((now - mtime))

    # Idle detection: >300s (5 min) since last state change
    if [[ $age -gt 300 ]]; then
        echo "#[fg=colour240]●"
        return
    fi

    case "$state" in
        working)  echo "#[fg=colour46]●" ;;   # bright green
        waiting)  echo "#[fg=colour226]●" ;;   # yellow
        error)    echo "#[fg=colour196]●" ;;   # red
        *)        echo "#[fg=colour240]●" ;;   # grey
    esac
}

# -----------------------------------------------------------
#  DISPATCH
# -----------------------------------------------------------
case "$COMPONENT" in
    worktime)    get_work_time ;;
    tokens)      get_tokens_today ;;
    agents)      get_active_agents ;;
    commits)     get_commits_today ;;
    branch)      get_git_branch ;;
    status)      get_git_status ;;
    context_pct) get_context_pct ;;
    git_sync)    get_git_sync ;;
    claude_state) get_claude_state ;;
    all)
        echo "WORK:      $(get_work_time)"
        echo "TOKENS:    $(get_tokens_today)"
        echo "AGENTS:    $(get_active_agents)"
        echo "COMMITS:   $(get_commits_today)"
        echo "BRANCH:    $(get_git_branch)"
        echo "STATUS:    $(get_git_status)"
        echo "CONTEXT:   $(get_context_pct)"
        echo "GIT_SYNC:  $(get_git_sync)"
        echo "STATE:     $(get_claude_state)"
        ;;
    *)
        echo "Usage: tmux-hud.sh {worktime|tokens|agents|commits|branch|status|context_pct|git_sync|claude_state|all}"
        ;;
esac
