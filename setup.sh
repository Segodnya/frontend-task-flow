#!/usr/bin/env bash
# Sets up Claude Code for frontend work in one project repository.
# Settings and plugins go to <repo>/.claude/ and are hidden from git via .git/info/exclude.
# Globally it changes only its own rules block in ~/.claude/CLAUDE.md and permissions.defaultMode
# in ~/.claude/settings.json when that key is not set yet.
# Re-running is safe: existing settings win over defaults.
set -euo pipefail

flow_dir=$(cd "$(dirname "$0")" && pwd)
usage="Usage: setup.sh --jira <url> --gitlab <host> [path to repository]
  --jira    Jira URL, e.g. https://example.atlassian.net
  --gitlab  GitLab host, e.g. gitlab.example.com"

say()  { printf '\n\033[1m→ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n\n%s\n' "$*" "$usage" >&2; exit 1; }

JIRA_URL= GITLAB_HOST= target=
while [ $# -gt 0 ]; do
  case $1 in
    --jira)   JIRA_URL=${2:-}; shift 2 ;;
    --gitlab) GITLAB_HOST=${2:-}; shift 2 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    -*) die "Unknown argument: $1" ;;
    *)  target=$1; shift ;;
  esac
done
[ -n "$JIRA_URL" ]    || die "Jira URL is not set (--jira)"
[ -n "$GITLAB_HOST" ] || die "GitLab host is not set (--gitlab)"
# Accept both "https://host/" and "host": glab wants a bare host name
GITLAB_HOST=${GITLAB_HOST#*://}; GITLAB_HOST=${GITLAB_HOST%%/*}
JIRA_URL=${JIRA_URL%/}
case $JIRA_URL in *://*) ;; *) JIRA_URL="https://$JIRA_URL" ;; esac

repo=$(git -C "${target:-$PWD}" rev-parse --show-toplevel 2>/dev/null) \
  || die "Run from inside the project repository or pass its path"
cd "$repo"
say "Repository: $repo"
say "Jira: $JIRA_URL, GitLab: $GITLAB_HOST"

say "1/4 Checking tools"
command -v brew   >/dev/null || { echo "Homebrew is missing (macOS, Linux, WSL): https://brew.sh"; exit 1; }
command -v claude >/dev/null || { echo "Claude Code is missing: npm i -g @anthropic-ai/claude-code"; exit 1; }
command -v node   >/dev/null || { echo "Node.js is missing: brew install node"; exit 1; }
for tool in jq glab jira-cli; do
  bin=${tool%-cli}
  command -v "$bin" >/dev/null || brew install "$tool"
done

say "2/4 Settings in .claude/settings.local.json, auto mode in ~/.claude/settings.json, agent rules in ~/.claude/CLAUDE.md"
mkdir -p .claude ~/.claude
settings=.claude/settings.local.json
[ -f "$settings" ] || echo '{}' > "$settings"
defaults=$(cat <<JSON
{
  "model": "opus[1m]",
  "effortLevel": "high",
  "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet", "GITLAB_HOST": "$GITLAB_HOST" },
  "permissions": { "deny": ["EnterPlanMode", "ExitPlanMode"] },
  "outputStyle": "Concise"
}
JSON
)
jq -s '.[0] * .[1]' <(echo "$defaults") "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"

# Claude Code reads auto mode only from user settings; in .claude/settings.local.json it is ignored
user_settings=~/.claude/settings.json
[ -s "$user_settings" ] || echo '{}' > "$user_settings"
jq '.permissions.defaultMode //= "auto"' "$user_settings" > "$user_settings.tmp"
cat "$user_settings.tmp" > "$user_settings" && rm "$user_settings.tmp"

# Rules shared by all repositories: replace only our own block, leave the rest of CLAUDE.md intact
claude_md=~/.claude/CLAUDE.md
start='<!-- frontend-task-flow:start -->'
end='<!-- frontend-task-flow:end -->'
touch "$claude_md"
if grep -qF "$start" "$claude_md" && ! grep -qF "$end" "$claude_md"; then
  echo "$claude_md has $start without $end: fix the file by hand and run the script again"; exit 1
fi
{ sed "\|$start|,\|$end|d" "$claude_md"; echo "$start"; cat "$flow_dir/claude-rules.md"; echo "$end"; } > "$claude_md.tmp"
# cat, not mv: CLAUDE.md may be a symlink into dotfiles
cat "$claude_md.tmp" > "$claude_md" && rm "$claude_md.tmp"

exclude=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$exclude")"
for p in .claude/settings.local.json .tmp-shots/; do
  grep -qxF "$p" "$exclude" 2>/dev/null || echo "$p" >> "$exclude"
done

say "3/4 Logins (interactive, once)"
glab auth status --hostname "$GITLAB_HOST" >/dev/null 2>&1 || glab auth login --hostname "$GITLAB_HOST"
[ -f ~/.config/.jira/.config.yml ] || { warn "Jira: create an API token in your Jira account security settings, then run:"; echo "  export JIRA_API_TOKEN=<token> && jira init --server $JIRA_URL"; }

say "4/4 Plugins (this repository only)"
for m in anthropics/claude-plugins-official mksglu/context-mode Segodnya/agents Segodnya/frontend-task-flow; do
  claude plugin marketplace add --scope local "$m" || true
done
for p in mattpocock-skills@claude-plugins-official typescript-lsp@claude-plugins-official context-mode@context-mode \
         segodnya-agents@segodnya-agents frontend-task-flow@frontend-task-flow; do
  claude plugin install --scope local "$p" || true
done

say "Done. Check: claude -> /skills (expect segodnya-agents:mr-ready, mattpocock-skills:grill-with-docs, frontend-task-flow:checklist-deploy), /mcp (chrome-devtools)"
