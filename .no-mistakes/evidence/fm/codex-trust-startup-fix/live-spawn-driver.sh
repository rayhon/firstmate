#!/usr/bin/env bash
# Manual live driver: runs the REAL bin/fm-spawn.sh against a REAL tmux server
# and a REAL codex TUI in a throwaway git project, to prove the Codex
# fresh-directory trust gate end to end.
set -u
ROOT=$1            # firstmate worktree root
MODE=${2:-crew}    # crew | relaunch
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-codex-live.XXXXXX")
SOCK="fmlive-$$-$RANDOM"
ID="codex-live-$$"
HOME_DIR="$LAB/fmhome"; PROJ="$LAB/project"; SHIM="$LAB/shim"; USERHOME="$LAB/userhome"
mkdir -p "$HOME_DIR"/{data,projects,state,config} "$PROJ" "$SHIM" "$USERHOME" "$LAB/codex-home"
touch "$HOME_DIR/state/.last-watcher-beat"
printf 'codex\n' > "$HOME_DIR/config/crew-harness"
mkdir -p "$HOME_DIR/data/$ID"
cat > "$HOME_DIR/data/$ID/brief.md" <<'EOF'
# Task
## Captain's intent
Reply exactly FM_CODEX_TRUST_OK and do nothing else.

## Firstmate spec
Reply exactly FM_CODEX_TRUST_OK and do nothing else.
EOF
cp "$HOME/.codex/auth.json" "$HOME/.codex/config.toml" "$LAB/codex-home/"
git -C "$PROJ" init -q
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
# real tmux behind a private socket
cat > "$SHIM/tmux" <<EOF
#!/usr/bin/env bash
exec $(command -v tmux) -L "$SOCK" "\$@"
EOF
# treehouse get: make a real isolated worktree and drop the pane's shell into it
cat > "$SHIM/treehouse" <<EOF
#!/usr/bin/env bash
set -u
[ "\${1:-}" = get ] || exit 0
slot="$LAB/wt-\$\$"
git -C "$PROJ" worktree add -q -b "slot-\$\$" "\$slot" >/dev/null 2>&1 || exit 1
cd "\$slot" || exit 1
exec "\${SHELL:-/bin/bash}"
EOF
for t in gh gh-axi; do printf '#!/usr/bin/env bash\nexit 0\n' > "$SHIM/$t"; done
chmod +x "$SHIM"/*
export CODEX_HOME="$LAB/codex-home"
echo "== lab=$LAB socket=$SOCK id=$ID"
# background pane watcher: records a timeline of distinct pane renders
(
  prev=
  for _ in $(seq 1 600); do
    cur=$("$SHIM/tmux" capture-pane -p -t "firstmate:fm-$ID" -S -60 2>/dev/null || true)
    if [ -n "$cur" ] && [ "$cur" != "$prev" ]; then
      { printf '===== %s =====\n' "$(date +%H:%M:%S)"; printf '%s\n' "$cur"; } >> "$LAB/pane-timeline.txt"
      prev=$cur
    fi
    sleep 0.4
  done
) &
WATCHER=$!

set -x
HOME="$USERHOME" CODEX_HOME="$LAB/codex-home" \
FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
FM_SPAWN_NO_GUARD=1 FM_GATE_REFUSE_BYPASS=1 \
PATH="$SHIM:$PATH" \
  "$ROOT/bin/fm-spawn.sh" "$ID" "$PROJ" --harness codex --mode no-mistakes --yolo off
rc=$?
set +x
kill "$WATCHER" 2>/dev/null || true
echo "== fm-spawn rc=$rc"
"$SHIM/tmux" list-windows -a 2>&1 | sed 's/^/win: /'
"$SHIM/tmux" capture-pane -p -t "firstmate:fm-$ID" -S -60 2>/dev/null | tee "$LAB/final-pane.txt"
echo "== LABKEEP $LAB SOCK $SOCK RC $rc"
