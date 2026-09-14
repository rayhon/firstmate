#!/usr/bin/env bash
# Adversarial live driver: REAL bin/fm-spawn.sh + REAL tmux + REAL git worktree,
# with a stand-in codex TUI that renders a chosen startup scene and records every
# keystroke Firstmate sends it. Proves what the startup gate does when the pane
# never reaches a working turn, and when the trust menu is not the verified one.
set -u
ROOT=$1; SCENE=$2
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-codex-adv.XXXXXX")
SOCK="fmadv-$$-$RANDOM"; ID="codex-adv-$SCENE-$$"
HOME_DIR="$LAB/fmhome"; PROJ="$LAB/project"; SHIM="$LAB/shim"; USERHOME="$LAB/userhome"
mkdir -p "$HOME_DIR"/{data,projects,state,config} "$PROJ" "$SHIM" "$USERHOME" "$HOME_DIR/data/$ID"
touch "$HOME_DIR/state/.last-watcher-beat"
printf 'codex\n' > "$HOME_DIR/config/crew-harness"
printf '# Task\n## Captain'"'"'s intent\nadversarial startup scene\n\n## Firstmate spec\nadversarial startup scene\n' > "$HOME_DIR/data/$ID/brief.md"
git -C "$PROJ" init -q
git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
cat > "$SHIM/tmux" <<EOF
#!/usr/bin/env bash
exec $(command -v tmux) -L "$SOCK" "\$@"
EOF
cat > "$SHIM/treehouse" <<EOF
#!/usr/bin/env bash
set -u
[ "\${1:-}" = get ] || exit 0
slot="$LAB/wt-\$\$"
git -C "$PROJ" worktree add -q -b "slot-\$\$" "\$slot" >/dev/null 2>&1 || exit 1
cd "\$slot" || exit 1
exec "\${SHELL:-/bin/bash}"
EOF
cat > "$SHIM/codex" <<EOF
#!/usr/bin/env bash
# stand-in codex TUI; scene chosen by the driver
set -u
KEYLOG="$LAB/keys.log"
case "$SCENE" in
  silent)
    printf '╭────────────────────────────╮\n│ >_ OpenAI Codex (v0.154.0) │\n╰────────────────────────────╯\n\n› Ask Codex to do anything\n' ;;
  changed)
    printf '  You are in a directory\n\n  Do you trust the contents of this folder?\n\n› 2. No, quit\n  1. Yes, continue\n' ;;
  unsafe)
    printf '  You are in a directory\n\n  Do you trust the contents of this directory?\n\n› 1. No, quit\n  2. Yes, continue\n' ;;
esac
while :; do
  if IFS= read -r -N1 c; then
    case "\$c" in
      \$'\n'|\$'\r') printf 'ENTER\n' >> "\$KEYLOG" ;;
      *) printf 'CHAR:%s\n' "\$c" >> "\$KEYLOG" ;;
    esac
  else
    sleep 0.2
  fi
done
EOF
for t in gh gh-axi; do printf '#!/usr/bin/env bash\nexit 0\n' > "$SHIM/$t"; done
chmod +x "$SHIM"/*
: > "$LAB/keys.log"
echo "== scene=$SCENE lab=$LAB id=$ID"
HOME="$USERHOME" \
FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" \
FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
FM_SPAWN_NO_GUARD=1 FM_GATE_REFUSE_BYPASS=1 \
FM_CODEX_READY_POLLS=20 FM_CODEX_POLL_INTERVAL=0.5 \
PATH="$SHIM:$PATH" \
  "$ROOT/bin/fm-spawn.sh" "$ID" "$PROJ" --harness codex --mode no-mistakes --yolo off
rc=$?
echo "== fm-spawn rc=$rc"
echo "== keys Firstmate sent into the codex pane:"; cat "$LAB/keys.log"
echo "== windows still alive on the fleet server:"
"$SHIM/tmux" list-windows -a 2>&1 | sed 's/^/win: /'
echo "== task status file:"; cat "$HOME_DIR/state/$ID.status" 2>/dev/null || echo "(none)"
"$SHIM/tmux" kill-server >/dev/null 2>&1 || true
rm -rf "$LAB"
