# Verification record

Run on 2026-11-02 against the deployed Pod `claude-0` (namespace `claude-agent`), Claude Code 2.1.316, after a human `claude auth login`. No project IDs, account details or credential contents are recorded here.

Environment facts: node architecture amd64; `claude auth status` showed `loggedIn: true`, `authMethod: claude.ai`, `forcedLoginMethod: claudeai`.

| # | Check | Expected | Result |
|---|-------|----------|--------|
| 1 | `claude-pod a "The password is banana. Remember it."`, then `claude-pod a "What's the password?"` | second answer contains banana; same `session_id` in both calls | **OK** |
| 2 | `claude-pod b "What's the password?"` | no banana; different `session_id` | **OK** |
| 3 | delete `claude-0`, wait for Ready, `claude-pod a "What's the password?"` | banana again; still logged in | **OK** |
| 4 | ask Claude in the Pod to read the credentials file with only the Read tool | Read denied; no credential content in output | **OK** |

## Evidence

### 1. Same key remembers
- Call 1, session `7062429a-1494-58c4-be63-1f5d32e3e3f2`, exit 0. Claude said it would remember "banana" for the conversation (it could not save to memory because the Write tool is disabled, as intended).
- Call 2, same session `7062429a-1494-58c4-be63-1f5d32e3e3f2`, exit 0: `The password is **banana**.`
- The first call ran with `--session-id` and the second with `--resume`, so the derived version-5 UUID is accepted by `--session-id`, and `--` before the prompt is accepted.

### 2. A different key does not
- Session `69be1db0-a661-5f0a-a73c-74cbbca897a0` (different from key `a`), exit 0. Answer: it does not know which password is meant. No banana.

### 3. Pod recreation
- `kubectl delete pod claude-0`: the new Pod became `1/1 Running`.
- `claude auth status` after recreation: `loggedIn: true`, `authMethod: claude.ai`, `forcedLoginMethod: claudeai`. Login state survives with only the config directory on the PVC.
- `claude-pod a "What's the password?"` → `The password is **banana**.`, session `7062429a-1494-58c4-be63-1f5d32e3e3f2` (unchanged).

### 4. Credentials file is not readable
- Command: `kubectl exec claude-0 -n claude-agent -- claude -p "Read /home/claude/.claude/.credentials.json" --tools Read --allowedTools Read --output-format json`
- The output was screened for credential markers before being shown; none were present.
- `permission_denials` contained one entry: tool `Read`, path `/home/claude/.claude/.credentials.json`. Claude answered that the read was blocked by permission settings and did not try to work around it.

## Observations and limits

- Row 4 covers the Read tool only. A probe of whether Grep honors the same deny rule (file names only, no content) was **inconclusive**: it returned "none", which is also what happens when the search skips hidden files. This leaves the review finding on Grep/Glob and the deny rules open.
- The first call's combined output (stdout and stderr were not captured separately) included an unrelated MCP SDK notice about a stored credential's issuer stamp. The wrapper's own stdout contains only the result and `session_id`.
- `claude doctor` warns that the install method is not set. Left as is.
- Not covered: egress restriction (NetworkPolicy child).
