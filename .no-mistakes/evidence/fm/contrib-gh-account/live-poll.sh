#!/usr/bin/env bash
# Live drive: real gh + real GitHub, disposable lab FM_HOME owning contextforce/agent-board PRs.
# usage: live-poll.sh <root-with-bin> <label> <pr numbers...>
set -u
ROOT=$1; LABEL=$2; shift 2
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || "$PWD/bin/fm-lab-home.sh" create "$LAB" >/dev/null
mkdir -p "$LAB/fakebin"; printf '#!/bin/sh\nexit 1\n' > "$LAB/fakebin/tmux"; chmod +x "$LAB/fakebin/tmux"  # keep default tmux server untouched
printf '# Backlog\n\n## Queued\n' > "$LAB/data/backlog.md"
for n in "$@"; do
  id=agentboard$n; url=https://github.com/contextforce/agent-board/pull/$n
  mkdir -p "$LAB/data/$id"
  printf -- '- [ ] %s - Contribution %s %s (repo: agent-board) (kind: ship)\n' "$id" "$id" "$url" >> "$LAB/data/backlog.md"
  jq -n --arg task "$id" --arg url "$url" '{schema:"fm-contributions.v1",task:$task,records:[{
    url:$url,kind:"pr",checked_at:"2026-01-01T00:00:00Z",error:null,pending:[],seen:[],verdict:null,observation:null}]}' \
    > "$LAB/data/$id/contributions.json"
done
echo "== [$LABEL] active gh account: $(gh api user --jq .login)"
echo "== [$LABEL] fm-contributions.sh poll output:"
env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE \
  PATH="$LAB/fakebin:$PATH" FM_HOME="$LAB" "$ROOT/bin/fm-contributions.sh" poll; echo "== [$LABEL] exit=$?"
echo "== [$LABEL] persisted records:"
for f in "$LAB"/data/*/contributions.json; do jq -c '.records[0]|{url,error,state:.observation.state,checked_at}' "$f"; done
echo "== [$LABEL] token persisted anywhere in lab? $(grep -rlF "$(gh auth token -u contextforce)" "$LAB" >/dev/null && echo YES || echo no)"
echo "== [$LABEL] active gh account after: $(gh api user --jq .login)"
rm -rf "$LAB"
