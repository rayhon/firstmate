#!/usr/bin/env bash
# Drive real fm-spawn.sh against a tmux fake that replays the REAL codex
# v0.154.0 screens captured from a live pane in this run.
set -u
. tests/fixtures.sh
DIALOG=$1 WORKING=$2
TMP=$(fm_test_tmproot fm-codex-replay)
case_dir=$TMP/c; home=$case_dir/home; proj=$case_dir/project; wt=$case_dir/wt
fakebin=$(fm_fakebin "$case_dir/fake")
export FM_FAKE_CODEX_STATE="$case_dir/state" FM_REPLAY_DIALOG=$DIALOG FM_REPLAY_WORKING=$WORKING
export FM_FAKE_TMUX_CALL_LOG="$case_dir/calls.log"; : > "$FM_FAKE_TMUX_CALL_LOG"
cat > "$fakebin/tmux" <<'T'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$FM_FAKE_TMUX_CALL_LOG"
state=$(cat "$FM_FAKE_CODEX_STATE" 2>/dev/null || true)
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "$FM_FAKE_PANE_PATH"; exit 0 ;;
  *"#{pane_id}"*) printf '%s\n' '%0'; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  kill-window) printf 'kill-window\n' >> "$FM_FAKE_TMUX_CALL_LOG"; exit 0 ;;
  capture-pane)
    case "$state" in
      dialog) cat "$FM_REPLAY_DIALOG" ;;
      working) cat "$FM_REPLAY_WORKING" ;;
      *) printf 'starting\n' ;;
    esac; exit 0 ;;
  send-keys)
    prev=; lit=
    for a in "$@"; do [ "$prev" = -l ] && { lit=$a; break; }; prev=$a; done
    [ -n "$lit" ] && { printf 'dialog\n' > "$FM_FAKE_CODEX_STATE"; exit 0; }
    case " $* " in *' Enter '*) [ "$state" = dialog ] && printf 'working\n' > "$FM_FAKE_CODEX_STATE" ;; esac
    exit 0 ;;
esac
exit 0
T
chmod +x "$fakebin/tmux"
fm_fake_exit0 "$fakebin" treehouse gh gh-axi codex
id=codex-replay-real
mkdir -p "$home/data/$id" "$home/projects" "$home/state" "$home/config"
printf 'codex\n' > "$home/config/crew-harness"
printf '# Task\n## Captain'"'"'s intent\nReply FM_CODEX_TRUST_OK.\n\n## Firstmate spec\nReply.\n' > "$home/data/$id/brief.md"
fm_git_worktree "$proj" "$wt" "wt-$id"
touch "$home/state/.last-watcher-beat"
FM_ROOT_OVERRIDE='' FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" \
  FM_DATA_OVERRIDE="$home/data" FM_PROJECTS_OVERRIDE="$home/projects" \
  FM_CONFIG_OVERRIDE="$home/config" FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
  FM_FAKE_PANE_PATH="$wt" FM_CODEX_READY_POLLS=8 FM_CODEX_POLL_INTERVAL=0 \
  PATH="$fakebin:$PATH" bin/fm-spawn.sh "$id" "$proj" --harness codex --mode no-mistakes --yolo off 2>&1 | grep -E 'spawned|error'
echo "bare-enters=$(grep -c '^send-keys -t [^ ]* Enter$' "$FM_FAKE_TMUX_CALL_LOG")"
echo "kill-window=$(grep -c '^kill-window$' "$FM_FAKE_TMUX_CALL_LOG")"
