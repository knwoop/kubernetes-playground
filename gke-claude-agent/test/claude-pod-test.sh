#!/usr/bin/env bash
# Exercise claude-pod against a stub kubectl; no cluster needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD="$HERE/../bin/claude-pod"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/bin"
fail=0
check() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: expected [$3] got [$2]"; fail=1; fi; }

# Stub kubectl. It records the argv of the session check and of the claude exec separately.
#   STUB_STATE=present|absent    answer to the session check
#   STUB_FAIL_ON=check|exec|all  make that kubectl call fail like a missing Pod
#   STUB_CLAUDE=<json file>      what the claude exec prints
#   STUB_CLAUDE_RC=<n>           exit status of the claude exec after printing
cat > "$TMP/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
kind=exec
for a in "$@"; do [[ "$a" == *"echo present"* ]] && kind=check; done
fail_pod() { echo 'Error from server (NotFound): pods "claude-0" not found' >&2; exit 1; }
[[ "${STUB_FAIL_ON:-}" == all || "${STUB_FAIL_ON:-}" == "$kind" ]] && fail_pod
printf '%s\0' "$@" > "$STUB_DIR/$kind.args"
if [[ $kind == check ]]; then echo "${STUB_STATE:-absent}"; exit 0; fi
cat "$STUB_CLAUDE"
exit "${STUB_CLAUDE_RC:-0}"
STUB
chmod +x "$TMP/bin/kubectl"
export PATH="$TMP/bin:$PATH" STUB_DIR="$TMP" STUB_CLAUDE="$TMP/c.json"

ok_json() { printf '{"type":"result","is_error":false,"result":"hi","session_id":"%s"}' "$1" > "$TMP/c.json"; }
# run <key> <prompt>: clears recorded argv first so a call that exits early cannot pass on stale data.
run() { rm -f "$TMP/check.args" "$TMP/exec.args"; "$POD" "$@"; }
argv() { python3 -I -c 'import sys; print("\n".join(open(sys.argv[1],"rb").read().decode().split("\0")[:-1]))' "$TMP/$1.args" 2>/dev/null; }
has() { argv "$1" | grep -qxF -- "$2" && echo yes || echo no; }
# value following a flag in the exec argv
after() { argv exec | awk -v f="$1" 'prev==f {print; exit} {prev=$0}'; }

uuid_a="$("$POD" --print-session-id a)"; uuid_b="$("$POD" --print-session-id b)"

# Golden value: if this changes, every existing conversation is orphaned. Change it only on purpose.
check "known key maps to the pinned uuid" "$("$POD" --print-session-id golden-key)" "60ffd38b-487e-59f3-b427-3070271e7a6e"
check "same key, same uuid" "$("$POD" --print-session-id a)" "$uuid_a"
check "different key, different uuid" "$([[ $uuid_a != "$uuid_b" ]] && echo yes)" "yes"

ok_json "$uuid_a"; export STUB_STATE=absent
out="$(run a "first")"
check "first call uses --session-id with the key's uuid" "$(after --session-id)" "$uuid_a"
check "first call does not use --resume" "$(has exec --resume)" "no"
check "first call prints result and session_id" "$out" $'hi\nsession_id: '"$uuid_a"

check "exec targets the namespace" "$(argv exec | awk 'prev=="-n" {print; exit} {prev=$0}')" "claude-agent"
check "exec targets the pod" "$(has exec claude-0)" "yes"
check "exec has no -t" "$(has exec -t)" "no"
check "exec has no -i" "$(has exec -i)" "no"
check "check call has no -t or -i" "$(has check -t)$(has check -i)" "nono"
check "claude runs in print mode" "$(has exec -p)" "yes"
check "output format is json" "$(after --output-format)" "json"
check "tools are limited by --tools" "$(after --tools)" "Read,Grep,Glob"
check "tools are limited by --allowedTools" "$(after --allowedTools)" "Read,Grep,Glob"
check "runs from the workspace" "$(argv exec | grep -c 'cd /workspace/repo')" "1"
check "prompt is the last argument, after --" "$(argv exec | tail -n 2 | tr '\n' '|')" "--|first|"

export STUB_STATE=present
run a "again" >/dev/null
check "later call uses --resume with the same uuid" "$(after --resume)" "$uuid_a"
check "later call does not use --session-id" "$(has exec --session-id)" "no"

export STUB_STATE=absent; ok_json "$uuid_b"
run b "x" >/dev/null
check "other key gets its own uuid" "$(after --session-id)" "$uuid_b"

p=$'say "hi" $HOME `id` $(id)\nsecond line'
run a "$p" >/dev/null
check "prompt reaches kubectl unchanged" "$(python3 -I -c 'import sys; print(open(sys.argv[1],"rb").read().split(b"\0")[-2].decode(), end="")' "$TMP/exec.args")" "$p"

printf '{"type":"result","is_error":true,"subtype":"error_during_execution","result":null,"errors":["boom"]}' > "$TMP/c.json"
err="$(run a "x" 2>&1 >/dev/null)"; rc=$?
check "is_error exits non-zero" "$([[ $rc -ne 0 ]] && echo yes)" "yes"
check "is_error message on stderr" "$([[ $err == *boom* ]] && echo yes)" "yes"

# A failed session check must stop the call: it must not be read as "no session yet" and must not reach claude.
ok_json "$uuid_a"
export STUB_FAIL_ON=check
err="$(run a "x" 2>&1 >/dev/null)"; rc=$?
unset STUB_FAIL_ON
check "failed session check exits 1" "$rc" "1"
check "failed session check shows the kubectl error" "$([[ $err == *NotFound* ]] && echo yes)" "yes"
check "failed session check never reaches claude" "$([[ -e $TMP/exec.args ]] && echo ran || echo stopped)" "stopped"

# A failed claude exec reports the kubectl error too.
export STUB_FAIL_ON=exec
err="$(run a "x" 2>&1 >/dev/null)"; rc=$?
unset STUB_FAIL_ON
check "failed exec exits non-zero" "$([[ $rc -ne 0 ]] && echo yes)" "yes"
check "failed exec shows the kubectl error" "$([[ $err == *NotFound* ]] && echo yes)" "yes"

# Claude printed valid JSON but the exec exited non-zero: still a failure, and no result on stdout.
export STUB_CLAUDE_RC=1
out="$(run a "x" 2>/dev/null)"; rc=$?
unset STUB_CLAUDE_RC
check "non-zero exec status with valid JSON exits non-zero" "$rc" "1"
check "non-zero exec status prints no result on stdout" "$out" ""

exit $fail
