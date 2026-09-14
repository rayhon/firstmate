#!/usr/bin/env bash
# Drive the real fm-spawn.sh CLI against real tmux + the real codex TUI.
set -u
ROOT=$1; LAB=$2
ID=live-codex-trust-$$
home="$LAB/home"; proj="$LAB/project"; stub="$LAB/stub"
mkdir -p "$home/data/$ID" "$home/projects" "$home/state" "$home/config" "$stub" "$LAB/codex-home"
cp ~/.codex/auth.json ~/.codex/config.toml "$LAB/codex-home/"
for b in treehouse gh gh-axi; do printf '#!/bin/sh\nexit 0\n' > "$stub/$b"; chmod +x "$stub/$b"; done
git init -q "$proj"; (cd "$proj" && git config user.email t@t && git config user.name t && echo hi > README.md && git add -A && git commit -qm init)
git init -q --bare "$proj.origin.git"; git -C "$proj" remote add origin "$proj.origin.git"; git -C "$proj" push -q origin HEAD 2>/dev/null
cat > "$home/data/$ID/brief.md" <<'EOF'
# Task
## Captain's intent
Reply exactly FM_CODEX_TRUST_OK and do nothing else.

## Firstmate spec
Reply exactly FM_CODEX_TRUST_OK and do nothing else.
EOF
printf 'codex\n' > "$home/config/crew-harness"
touch "$home/state/.last-watcher-beat"
SOCKET="$LAB/tmux.sock"
tmux -S "$SOCKET" new-session -d -s firstmate -n main -x 160 -y 45
PID=$(tmux -S "$SOCKET" display-message -p '#{pid}')
export TMUX="$SOCKET,$PID,0"
export CODEX_HOME="$LAB/codex-home"
HOME="$home" FM_HOME="$home" FM_ROOT_OVERRIDE='' \
  FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
  FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
  FM_SPAWN_NO_GUARD=1 PATH="$stub:$PATH" \
  "$ROOT/bin/fm-spawn.sh" "$ID" "$proj" --harness codex --mode no-mistakes --yolo on 2>&1
rc=$?
echo "fm-spawn rc=$rc"
echo "--- windows ---"; tmux -S "$SOCKET" list-windows -a 2>&1
echo "--- pane ---"; tmux -S "$SOCKET" capture-pane -p -t "fm-$ID" -S -60 2>&1 | grep -v '^$' | tail -30
