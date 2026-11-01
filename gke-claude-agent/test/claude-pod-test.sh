#!/usr/bin/env bash
# Exercise claude-pod against a stub kubectl; no cluster needed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD="$HERE/../bin/claude-pod"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/bin"
fail=0
check() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: expected [$3] got [$2]"; fail=1; fi; }

# Stub kubectl. STUB_STATE=present|absent, STUB_KUBECTL_FAIL=1, STUB_CLAUDE=<json file>.
cat > "$TMP/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
[[ -n "${STUB_KUBECTL_FAIL:-}" ]] && { echo 'Error from server (NotFound): pods "claude-0" not found' >&2; exit 1; }
for a in "$@"; do
  if [[ "$a" == *"echo present"* ]]; then echo "${STUB_STATE:-absent}"; exit 0; fi
done
printf '%s\0' "$@" > "$STUB_ARGS"
cat "$STUB_CLAUDE"
STUB
chmod +x "$TMP/bin/kubectl"
export PATH="$TMP/bin:$PATH" STUB_ARGS="$TMP/args"
uuid_a="$("$POD" --print-session-id a)"; uuid_b="$("$POD" --print-session-id b)"
ok_json() { printf '{"type":"result","is_error":false,"result":"hi","session_id":"%s"}' "$1" > "$TMP/c.json"; }
has_arg() { tr '\0' '\n' < "$TMP/args" | grep -qxF -- "$1" && echo yes || echo no; }

check "same key, same uuid" "$("$POD" --print-session-id a)" "$uuid_a"
check "different key, different uuid" "$([[ $uuid_a != "$uuid_b" ]] && echo yes)" "yes"

export STUB_CLAUDE="$TMP/c.json"
ok_json "$uuid_a"; export STUB_STATE=absent
out="$("$POD" a "first")"
check "first call uses --session-id" "$(has_arg --session-id)" "yes"
check "first call does not use --resume" "$(has_arg --resume)" "no"
check "first call prints result and session_id" "$out" $'hi\nsession_id: '"$uuid_a"

export STUB_STATE=present
"$POD" a "again" >/dev/null
check "later call uses --resume" "$(has_arg --resume)" "yes"
check "later call does not use --session-id" "$(has_arg --session-id)" "no"
check "tools are limited" "$(has_arg Read,Grep,Glob)" "yes"

export STUB_STATE=absent; ok_json "$uuid_b"
"$POD" b "x" >/dev/null
check "other key gets its own uuid" "$(tr '\0' '\n' < "$TMP/args" | grep -cxF "$uuid_b")" "1"

p=$'say "hi" $HOME `id` $(id)\nsecond line'
"$POD" a "$p" >/dev/null
last="$(python3 -I -c 'import sys; print(open(sys.argv[1],"rb").read().split(b"\0")[-2].decode(), end="")' "$TMP/args")"
check "prompt reaches kubectl unchanged" "$last" "$p"

printf '{"type":"result","is_error":true,"subtype":"error_during_execution","result":null,"errors":["boom"]}' > "$TMP/c.json"
err="$("$POD" a "x" 2>&1 >/dev/null)"; rc=$?
check "is_error exits non-zero" "$([[ $rc -ne 0 ]] && echo yes)" "yes"
check "is_error message on stderr" "$([[ $err == *boom* ]] && echo yes)" "yes"

export STUB_KUBECTL_FAIL=1
err="$("$POD" a "x" 2>&1 >/dev/null)"; rc=$?
check "kubectl failure exits non-zero" "$([[ $rc -ne 0 ]] && echo yes)" "yes"
check "kubectl error is shown" "$([[ $err == *NotFound* ]] && echo yes)" "yes"

exit $fail
