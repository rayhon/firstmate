#!/usr/bin/env bash
# Reproduce the settle-suite spawn (codex crew harness, fake pane with no
# capture-pane output) directly against the real fm-spawn.sh CLI.
set -u
. tests/fixtures.sh
TMP=$(fm_test_tmproot fm-settle-repro)
case_dir=$TMP/c; home=$case_dir/home; proj=$case_dir/project; wt=$case_dir/wt
fakebin=$(fm_fakebin "$case_dir/fake")
cat > "$fakebin/tmux" <<'T'
#!/usr/bin/env bash
set -u
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "$FM_FAKE_PANE_PATH"; exit 0 ;;
  *"#{pane_id}"*) printf '%s\n' '%0'; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
esac
exit 0
T
chmod +x "$fakebin/tmux"
fm_fake_exit0 "$fakebin" treehouse gh gh-axi codex
mkdir -p "$home/data/settle-repro" "$home/projects" "$home/state" "$home/config"
printf 'codex\n' > "$home/config/crew-harness"
printf '# Task\n## Captain'"'"'s intent\nx\n\n## Firstmate spec\ny\n' > "$home/data/settle-repro/brief.md"
fm_git_worktree "$proj" "$wt" wt-settle-repro
touch "$home/state/.last-watcher-beat"
FM_ROOT_OVERRIDE='' FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" \
  FM_DATA_OVERRIDE="$home/data" FM_PROJECTS_OVERRIDE="$home/projects" \
  FM_CONFIG_OVERRIDE="$home/config" FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
  FM_FAKE_PANE_PATH="$wt" FM_CODEX_READY_POLLS=3 FM_CODEX_POLL_INTERVAL=0 \
  PATH="$fakebin:$PATH" bin/fm-spawn.sh settle-repro "$proj" --mode no-mistakes --yolo off
echo "fm-spawn rc=$?"
