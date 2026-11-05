#!/usr/bin/env bash
# Builds the sandbox upload from a branch (default sandbox-base) and refuses to finish if anything that must not be uploaded is inside.
# sandbox-base already has .github, .devcontainer, the Docker files, scripts/, docs/, README.md and the production-server files removed;
# this script leaves out this .sandbox/ folder and checks that nothing of that kind came back (e.g. from a task branch).
# Usage (from the repo root): bash .sandbox/make-sandbox-zip.sh [branch] [output dir, default: the repo's parent folder]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BRANCH="${1:-sandbox-base}"
OUT="${2:-$(dirname "$REPO")}"
NAME="linkding"
ZIP="$OUT/$NAME-sandbox.zip"

git -C "$REPO" rev-parse --verify --quiet "$BRANCH" >/dev/null || { echo "No branch '$BRANCH' in $REPO"; exit 1; }
echo "Branch $BRANCH @ $(git -C "$REPO" log --oneline -1 "$BRANCH")"

files=()
skipped=0
while IFS= read -r -d '' path; do
	case "$path" in
		.sandbox/*) skipped=$((skipped + 1)) ;;
		*) files+=("$path") ;;
	esac
done < <(git -C "$REPO" ls-tree -r -z --name-only "$BRANCH")
echo "Files: ${#files[@]} packed, $skipped left out"

# git archive packs committed files only: no .git, no node_modules, no .venv, no data, no build output.
rm -f "$ZIP"
git -C "$REPO" --literal-pathspecs archive --format=zip --prefix="$NAME/" -o "$ZIP" "$BRANCH" -- "${files[@]}"

fail=0
check() { # name, count, expected
	if [ "$2" != "$3" ]; then echo "  ✗ $1: $2 (expected $3)"; fail=1; else echo "  ✓ $1"; fi
}
list="$(unzip -Z1 "$ZIP")"
check ".git entries"            "$(grep -c '/\.git/' <<<"$list" || true)" 0
check "node_modules, .venv, data, static" "$(grep -cE "node_modules/|/\.venv/|^$NAME/(data|static)/" <<<"$list" || true)" 0
check ".env files (except .env.sample)" "$(grep -E '/\.env' <<<"$list" | grep -vc '\.env\.sample$' || true)" 0
check "agent / AI-tool files"   "$(grep -ciE '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$|copilot-instructions\.md$|(^|/)SKILL\.md$|(^|/)\.mcp\.json$|(^|/)llms(-full)?\.txt$|/\.(cursor|codex|gemini|windsurf|claude|agents|kiro)/|\.cursorrules$' <<<"$list" || true)" 0
check ".github / .devcontainer" "$(grep -cE "^$NAME/\.(github|devcontainer)/" <<<"$list" || true)" 0
check "Docker / deploy files"   "$(grep -ciE "^$NAME/(docker|scripts|docs)/|^$NAME/(docker-compose[^/]*\.ya?ml|\.dockerignore|uwsgi\.ini|supervisord[^/]*\.conf|bootstrap\.sh|install-linkding\.sh)$" <<<"$list" || true)" 0
check "README.md (COMMANDS.md instead)" "$(grep -c "^$NAME/README\.md$" <<<"$list" || true)" 0
check "COMMANDS.md present"     "$(grep -c "^$NAME/COMMANDS\.md$" <<<"$list" || true)" 1
check "this .sandbox folder"    "$(grep -c "^$NAME/\.sandbox/" <<<"$list" || true)" 0
check "requirements + lockfiles present" "$(grep -cE "^$NAME/(requirements\.txt|requirements-dev\.txt|uv\.lock|package-lock\.json)$" <<<"$list" || true)" 4
check "samples present"         "$(grep -c "^$NAME/samples/.*\.html$" <<<"$list" || true)" 6
check "uwsgi not required"      "$(unzip -p "$ZIP" "$NAME/requirements.txt" | grep -c '^uwsgi' || true)" 0
check "Playwright pinned to 1.58.0" "$(unzip -p "$ZIP" "$NAME/requirements-dev.txt" | grep -c '^playwright==1.58.0' || true)" 1
check "private registry URLs"   "$(unzip -p "$ZIP" | grep -acE 'artifactor[y]|\.jfrog\.io' || true)" 0
check "API keys"                "$(unzip -p "$ZIP" | grep -acE 'sk-[A-Za-z0-9_-]{20,}|sk-ant-|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_|BEGIN [A-Z ]*PRIVATE KEY' || true)" 0

ls -lh "$ZIP" | awk '{print "Size:", $5, " ->", $9}'
if [ "$fail" = 1 ]; then echo "NOT OK: fix the items above before uploading."; rm -f "$ZIP"; exit 1; fi
echo "OK: upload $ZIP with 'Mount files' (extraction path /workspace)."
