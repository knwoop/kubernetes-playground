# Research evidence: raw findings per area

Raw findings of the four research areas behind `research.md` (2026-11-01). Facts only; each file lists its sources and what was searched without finding.

---

# Claude Code facts for a non-root GKE Pod PoC (research findings)

Researched 2026-11-01. All doc pages fetched from code.claude.com on that date (live docs; pages carry no per-page date, so the "version" is the doc state on 2026-11-01). npm registry `latest` of @anthropic-ai/claude-code on that date: 2.1.316 (https://registry.npmjs.org/@anthropic-ai/claude-code/latest). Facts only, no recommendations. No experiments were run.

---------------------------------------------------------------------
## 1. Installer, non-root, binary location, dependencies, auto-update
---------------------------------------------------------------------

Source: https://code.claude.com/docs/en/setup (Advanced setup), https://code.claude.com/docs/en/troubleshoot-install, https://registry.npmjs.org/@anthropic-ai/claude-code/latest

### Install methods that exist
- Native installer (labelled "Native Install (Recommended)"): `curl -fsSL https://claude.ai/install.sh | bash` (macOS, Linux, WSL). Accepts a channel or version: `... | bash -s stable`, `... | bash -s 2.1.89`. "The channel you choose at install time becomes your default for auto-updates."
- Homebrew cask, WinGet (not relevant to Linux container).
- Linux package managers (signed repos at downloads.claude.ai): apt (Debian/Ubuntu), dnf (Fedora/RHEL), apk (Alpine). Channels `stable` and `latest`. Doc: "Package manager installations do not auto-update through Claude Code; updates arrive through your normal system upgrade workflow." (apt/dnf need sudo/root to install.)
- npm: `npm install -g @anthropic-ai/claude-code`. Doc: "requires Node.js 22 or later. On an older Node.js version, npm prints an EBADENGINE warning ... the package downloads a native binary that doesn't use your Node.js at runtime." "The installed claude binary does not itself invoke Node." npm pulls a per-platform optional dependency; supported: darwin-arm64, darwin-x64, linux-x64, linux-arm64, linux-x64-musl, linux-arm64-musl, win32-x64, win32-arm64. "Don't install with sudo. Claude Code runs npm without sudo when it updates itself, so an install that needs sudo can't update automatically." Registry metadata for 2.1.316: engines node >=22.0.0, bin `claude` -> `bin/claude.exe`, optionalDependencies include @anthropic-ai/claude-code-linux-x64, -linux-arm64, -linux-x64-musl, -linux-arm64-musl.
- Manual binary: each release has `https://downloads.claude.ai/claude-code-releases/{VERSION}/manifest.json` (+ `.sig` from 2.1.89) with SHA256 per platform. Linux binaries are not individually code-signed; verify via the signed manifest.
- Also `claude install [version|stable|latest]` subcommand ("Install or reinstall the native binary") per https://code.claude.com/docs/en/cli-reference.

### Where files go (native installer, macOS/Linux)
Doc (troubleshoot-install, "Check directory permissions"): the install writes to
- `~/.claude/downloads/` - downloaded binary
- `~/.local/bin/` - the `claude` launcher
- `~/.local/share/claude/` - each version (setup page: launcher "`~/.local/bin/claude` as a symlink into `~/.local/share/claude/versions/`")
- `~/.local/state/claude/` - lock files
- `~/.cache/claude/` - staged downloads
- `~/.claude.json` - "your global config file, where the installer records the install method"
"If you set XDG_DATA_HOME, XDG_STATE_HOME, or XDG_CACHE_HOME, the install uses those in place of ~/.local/share, ~/.local/state, and ~/.cache. If you set CLAUDE_CONFIG_DIR, the global config file lives under that directory instead of your home directory."
Non-root: no root requirement is stated for the native installer; the page says install failures on permissions name the path that could not be written and the fix is making those dirs writable by the user (`sudo chown -R $(whoami) ~/.local`). The Docker note: "installing as root into `/` can cause hangs. Set a working directory before running the installer ... `WORKDIR /tmp` then `RUN curl -fsSL https://claude.ai/install.sh | bash`".
Auto-update-relevant: native updates download new versions under `~/.local/share/claude/versions/` and the launcher symlink in `~/.local/bin/`; "The native installer deletes old versions ... keeps the two newest versions and deletes the rest."

### System requirements / dependencies
Setup page "System requirements": Ubuntu 20.04+, Debian 10+, Alpine Linux 3.19+ (also macOS 13+, Windows); 4 GB+ RAM; x64 or ARM64; internet required; shell Bash/Zsh. "Additional dependencies: ripgrep: usually included with Claude Code."
- glibc vs musl: the installer picks a glibc or musl binary variant (troubleshoot-install "Linux musl or glibc binary mismatch": error `Error loading shared library libstdc++.so.6` can appear if installer misdetects musl on a glibc system with musl cross packages; check with `ldd --version`). No minimum glibc version number was found in the docs.
- Alpine/musl: "requires `bash` and `curl` for the install command, and `libgcc`, `libstdc++`, and `ripgrep` at runtime ... then set `USE_BUILTIN_RIPGREP=0`" (`apk add bash curl libgcc libstdc++ ripgrep`; set via settings.json `env`).
- git: not listed as a Linux install dependency on the setup page. (The Bash tool/git operations by the agent naturally use git if present; docs' Windows note says Git for Windows recommended for the Bash tool only on Windows.) curl is needed for the install command (Alpine note says it is absent there by default).
- Low memory: troubleshoot-install has "Install killed on low-memory Linux servers" (exit code 137 section).

### Auto-update
Setup page "Update Claude Code": "Native installations automatically update in the background." "Claude Code checks for updates on startup and periodically while running. Updates download and install in the background, then take effect the next time you start Claude Code." npm global installs: "If an npm global install can't auto-update because the npm global directory isn't writable, Claude Code shows a one-time notice at startup, and claude doctor lists the available fixes."
Ways to disable (quoted):
- `DISABLE_AUTOUPDATER` = "1" in settings.json `env` (or env var): "`DISABLE_AUTOUPDATER` only stops the background check; `claude update` and `claude install` still work." (env-vars: "Set to 1 to disable automatic background updates. Manual claude update still works. Use DISABLE_UPDATES to block both")
- `DISABLE_UPDATES` = 1: "block all updates including manual claude update and claude install. Stricter than DISABLE_AUTOUPDATER." Setup page also recommends it for shared/network storage because "Setting DISABLE_AUTOUPDATER alone isn't enough, because users can still run claude update and claude install."
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (any non-empty value, even `0`/`false`) disables "auto-updates, telemetry, error reporting, the /feedback command, ..., release notes ...".
- Settings: `autoUpdatesChannel` ("latest" default | "stable"), `minimumVersion` floor. Verify with `claude doctor`: shows `Auto-updates` line, e.g. `disabled (set by env: DISABLE_AUTOUPDATER)`.
- Binary integrity note: running session reads parts of the executable from disk; "If the file becomes unreadable mid-session, for example because it was truncated or deleted ... the session crashes" (setup page, "Install on network storage") - relevant because native auto-update prunes old versions.
- `DISABLE_INSTALLATION_CHECKS=1` "disable installation warnings" (env-vars).
Whether the update attempt fails when install dir is read-only: docs reference "`Auto-update failed` in the session footer" (troubleshoot-install#auto-update-failed) and `claude doctor` reports last update attempt; exact read-only-filesystem behaviour not stated beyond that.

---------------------------------------------------------------------
## 2. CLAUDE_CONFIG_DIR contents and files outside it
---------------------------------------------------------------------

Sources: https://code.claude.com/docs/en/env-vars ; https://code.claude.com/docs/en/claude-directory ; https://code.claude.com/docs/en/authentication ; https://code.claude.com/docs/en/sessions

- env-vars `CLAUDE_CONFIG_DIR`: "Override the configuration directory (default: ~/.claude). All settings, session history, and plugins are stored under this path. For credentials, see where Claude Code stores credentials. ... In a settings file, write the absolute path. Ignored in project and local settings."
- claude-directory: "If you set CLAUDE_CONFIG_DIR, every ~/.claude path on this page lives under that directory instead. The same applies to `.claude.json`, which otherwise sits at `~/.claude.json`." So with CLAUDE_CONFIG_DIR set, the global config file `.claude.json` is inside the config dir (also stated in troubleshoot-install: "the global config file lives under that directory instead of your home directory").
- Credentials (authentication#credential-management): "On Linux, credentials are stored in `~/.claude/.credentials.json` with file mode 0600." "If you've set the CLAUDE_CONFIG_DIR environment variable, Claude Code keeps the `.credentials.json` file under that directory instead." (On macOS the Keychain is used first; Linux has no keychain path documented.)
- `~/.claude.json` role (claude-directory file table): "App state, account details, UI toggles, personal MCP servers. If it's missing, Claude Code creates it when you start a session or run a subcommand such as `claude auth status`, but not for --version or --help." The page says "Don't delete ~/.claude.json, ~/.claude/settings.json, or ~/.claude/plugins/: those hold your account details, preferences, and installed plugins." Per-project entry in it holds "trust, history, MCP servers" (claude purge output). The installer records the install method in it. The exact key names for onboarding (hasCompletedOnboarding, oauthAccount) were NOT found on the pages fetched (see Not found list).
- Authentication page: "Each directory [CLAUDE_CONFIG_DIR] has its own settings, session history, and claude.ai login or API key." Exception: "Separate directories don't keep two Claude Console sign-ins without an API key apart, because Claude Code stores that kind of sign-in outside the configuration directory" (Anthropic profile files live in `~/.config/anthropic` by default; irrelevant for claude.ai login).
- Contents listed under `~/.claude/` (claude-directory "Application data"): `.credentials.json` (keep), `settings.json`, `settings.local.json` (project), `projects/<project>/<session>.jsonl` transcripts, `projects/<project>/<session>/subagents|tool-results|mcp-tasks/`, `projects/<project>/memory/` (auto memory; not swept), `history.jsonl` (prompt history, "Kept until you delete"), `file-history/<session>/`, `plans/`, `debug/`, `paste-cache/`, `session-env/`, `sessions/` (one small file per running session, removed on exit), `tasks/`, `shell-snapshots/` (removed on clean exit), `backups/` (last 5 copies of .claude.json), `stats-cache.json`, `remote-settings.json`, `policy-limits.json`, `cache/changelog.md`, `plugins/`, `agent-memory/`, `jobs/`, `daemon/`, legacy `todos/ statsig/ logs/`. Retention: `cleanupPeriodDays` default 30, min 1; sweep skipped with `--bare`.
- Temp locations OUTSIDE the config dir: scratchpad and pasted images go under the temp dir (`/tmp/claude-<uid>/<project>/<session-id>/scratchpad/` on Linux, or under `$TMPDIR`; controlled by `CLAUDE_CODE_TMPDIR`, which appends `/claude-{uid}/`). Native binary/versions under `~/.local/share/claude`, `~/.local/bin`, caches `~/.cache/claude`, locks `~/.local/state/claude` (see Q1).
- Project dir encoding (sessions#where-transcripts-are-stored): "`~/.claude/projects/<project>/<session-id>.jsonl`, where `<project>` is your working directory path with non-alphanumeric characters replaced by `-`. For a working directory whose converted name exceeds 200 characters, Claude Code truncates the name to 200 characters and appends a hash of the full path." Example in claude-directory scratchpad text: `/Users/you/my-project` -> `-Users-you-my-project`.
- Override of project dir name: `CLAUDE_CODE_PROJECT_DIR_NAME` (v2.1.234+; 1-64 letters/digits/hyphens/underscores; only honoured when `CLAUDE_CONFIG_DIR` is set; must be in process env, not settings env). Example: `CLAUDE_CONFIG_DIR=/srv/tenant-a CLAUDE_CODE_PROJECT_DIR_NAME=work claude` -> transcripts in `/srv/tenant-a/projects/work/`, auto memory in `/srv/tenant-a/projects/work/memory/`, "whatever the working directory is". If later launched without the variable, the derived directory is used again; "`claude --resume <session-id>` finds a session stored under either name."
- Related: `CLAUDE_CODE_SKIP_PROMPT_HISTORY=1` skips transcripts and prompt history; `CLAUDE_CODE_TRANSCRIPT_LOCAL_GC` limits growth of -p/SDK transcripts (sessions page table).
- `claude auth status` JSON includes `configDirectory` (v2.1.268+) naming the config dir in use (cli-reference).

---------------------------------------------------------------------
## 3. `claude auth login` / status / logout in headless containers
---------------------------------------------------------------------

Sources: https://code.claude.com/docs/en/cli-reference ; https://code.claude.com/docs/en/authentication ; https://code.claude.com/docs/en/troubleshoot-install (section "OAuth login fails in WSL2, SSH, or containers") ; https://code.claude.com/docs/en/errors ; https://code.claude.com/docs/en/network-config

### Commands and flags (cli-reference table, verbatim)
- `claude auth login`: "Sign in to your Anthropic account. Use `--email` to pre-fill your email address, `--sso` to force SSO authentication, and `--console` to sign in with Anthropic Console for API usage billing instead of a Claude subscription."
  - A `--claudeai` flag is NOT documented in the CLI reference table (see Not found). Docs do mention `forceLoginMethod` setting values `"claudeai"` / `"console"` (authentication page) which pre-select the login method; "On Claude Code v2.1.212 or later, every login path listed here applies forceLoginMethod." `--console` is documented as the opt-in for Console; absent that flag, doc text describes default as claude.ai subscription login.
- `claude auth logout`: "Log out from your Anthropic account."
- `claude auth status`: "Show authentication status as JSON. Use `--text` for human-readable output. Exits with code 0 if logged in, 1 if not. The JSON includes a `configDirectory` field ... (v2.1.268 or later). The JSON's `authMethod` field is one of `none`, `claude.ai`, `oauth_token`, `api_key`, `api_key_helper`, or `third_party`."
- Also `claude setup-token` (generates 1-year token printed to terminal for CLAUDE_CODE_OAUTH_TOKEN) - listed for completeness; forbidden in this PoC.

### Headless / container flow (troubleshoot-install, verbatim excerpts)
"If no browser opens, or the browser signs you in and then shows a connection error for a localhost address, you can finish signing in without fixing either problem. Sign in through the separate login URL that the terminal shows above its paste prompt instead:
1. Copy the login URL ... With `claude auth login`, copy the URL that it prints.
2. Open the URL in a browser on your local machine and sign in. The browser then shows a code instead of returning to localhost.
3. Paste that code into the terminal at the prompt that begins `Paste code here`."
"If pasting the code into the interactive prompt does nothing ... use `claude auth login` instead, which reads the pasted code from standard input." Also: "If the browser doesn't open automatically during login, press `c` to copy the OAuth URL". Error: `OAuth error: Invalid code. Please make sure the full code was copied` = code expired or truncated. `BROWSER` env var can point at a browser path (WSL2 example).
Authentication page: "If your browser shows a login code instead of redirecting back after you sign in, paste it into the terminal at the `Paste code here if prompted` prompt. When login completes, the terminal shows `Login successful`."

### Credential storage on Linux; persistence; refresh
- File: `~/.claude/.credentials.json`, mode 0600, or under `CLAUDE_CONFIG_DIR` when set (authentication#credential-management). Claude Code manages it through `/login` and `/logout`. `/logout` "removes all stored credentials" and "resets your first-launch setup state, so the next time you run claude it walks you through login and setup again."
- Only config dir persisted: docs state per-directory login (`Each directory has its own settings, session history, and claude.ai login or API key`) and a devcontainer page link ("a dev container that keeps your credentials in a volume", https://code.claude.com/docs/en/devcontainer.md#persist-authentication-and-settings-across-rebuilds - linked, not fetched). Authentication page: "you ran `claude auth login` in your shell before your first session, or you rebuilt a dev container that keeps your credentials in a volume" -> the login prompt is skipped. Caveat listed: "Before v2.1.290, the prompt appeared during setup whether or not you were signed in." (so first-run setup may still show login on older versions).
- Refresh: errors page "Login expired": "Claude Code tried to renew your saved claude.ai login and the OAuth service rejected the stored refresh token, so Claude Code cleared the saved credentials. After that, each model request stops locally ... because only /login can create new credentials." network-config: "`platform.claude.com`: ... OAuth token exchange, refresh, and revocation also go to this host for claude.ai accounts." troubleshoot-install: "Parallel sessions on one machine share a saved login and coordinate its renewal so that only one process refreshes the token at a time." "If this happens frequently, check that your system clock is accurate, as token validation depends on correct timestamps." Troubleshoot note: before v2.1.211 two sessions renewing with the same token could revoke the saved login. Token lifetime / access-token TTL value was not found.
- `/status` row `Login` shows `Expired - log in again` (v2.1.210+); startup warning `Your login expires in 3 days · run /login to renew` (informational). Renewing matters for unattended sessions: "A background session in agent view ... that outlives the login stops making progress once the credential expires and can't recover until you sign in again."

### Not logged in with `claude -p`
- headless page: "Claude Code exits with code 0 on success and a non-zero code when the run fails ... When a failure happens inside the run, such as missing authentication, Claude Code prints the failure as the result on stdout."
- errors page "Not logged in": message `Not logged in · Please run /login` ("No valid credential is available for this session"). "Interactive, -p, and Agent SDK runs report the same condition as Not logged in and write [`Could not resolve authentication method...`] only to their debug log."
- errors page "Login expired": "In non-interactive mode (-p) and the Agent SDK, the message reads `Failed to authenticate: OAuth session expired and could not be refreshed`, and the structured error code is `authentication_failed`." (api_retry event `error` field enumerates `authentication_failed`, `oauth_org_not_allowed`, `account_on_hold`, `billing_error`, ...; headless page.)
- Exact exit code value for the not-logged-in `-p` run and exact JSON for it (is_error/subtype) are not stated in docs (see Not found). SDK result type: error subtypes are `error_max_turns`, `error_during_execution`, `error_max_budget_usd`, `error_max_structured_output_retries`; `startup_failure_reason` is set only on known startup failures (typescript SDK ref). `claude auth status` exits 1 when not logged in (usable as a precheck).
- Interaction with forbidden env vars (authentication precedence, for awareness): order is cloud-provider vars, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` ("In non-interactive mode (-p), the key is always used when present"), apiKeyHelper, `CLAUDE_CODE_OAUTH_TOKEN`, Anthropic profile/federation (`~/.config/anthropic`), then subscription OAuth from /login (7th, "the default for Claude Pro, Max, Ultra, Team, and Enterprise users"). `--bare` mode "never reads OAuth credentials or the system keychain" (headless page) and "does not use your subscription login".
- Plan eligibility: "Claude Code requires a Pro, Max, Ultra, Team, Enterprise, or Console account. The free claude.ai plan does not include Claude Code access."

---------------------------------------------------------------------
## 4. Session semantics for `claude -p`
---------------------------------------------------------------------

Sources: https://code.claude.com/docs/en/cli-reference ; https://code.claude.com/docs/en/headless ; https://code.claude.com/docs/en/sessions ; https://code.claude.com/docs/en/errors ; https://code.claude.com/docs/en/agent-sdk/typescript

- `--session-id`: "Use a specific session ID for the conversation (must be a valid UUID)." Example `claude --session-id "550e8400-e29b-41d4-a716-446655440000"`. (cli-reference.) Behaviour when the ID already exists: NOT documented (see Not found). The TypeScript SDK `sessionId` option: "Use a specific UUID for the session instead of auto-generating one". Docs note a "wrapper-injected `--session-id`" as a harmless global flag in Remote Control context (errors page).
- `--resume` / `-r`: "Resume a specific session by ID or name, or show an interactive picker ... you can pass the absolute path to a session's .jsonl transcript file. ... When you pass a session ID, Claude Code searches the current project directory and its git worktrees, then every other project on this machine. Before v2.1.223, the ID search covered only the current project directory and its git worktrees." Sessions page: cross-project search "resolves the ID only when exactly one other project holds a transcript with messages for it, so a hand-copied duplicate makes Claude Code report not-found". Headless page: "You can run the two commands from different directories: Claude Code finds the session by its ID in any project on this machine." Transcripts themselves are stored under the cwd-encoded project dir (Q2).
- `--resume` for a nonexistent ID: stderr text `No conversation found with session ID: <session-id>`; "Claude Code exits with code 1 after showing the message" (errors page, "No conversation found with the session ID"). Causes listed: mistyped ID, deleted transcript (30-day retention default), different machine, duplicate copies. Whether this error is also emitted as JSON on stdout under `--output-format json` is not documented.
- `--resume` unreadable transcript: `Failed to resume the conversation.` / `Run claude --resume <session-id> to retry, or claude to start a new session.` exit code 1 (documented for the interactive picker path).
- `--continue` / `-c`: "Load the most recent conversation in the current directory ... Skips sessions created with `claude -p` or the Agent SDK, and sessions whose first prompt was /loop. `claude -p --continue` includes -p, SDK, and /loop sessions." (cli-reference). Sessions page: sessions "created with claude -p or the Agent SDK" are left out of the picker and plain `--continue`, but "You can still resume one by passing its session ID to `claude --resume <session-id>`." `--continue` is cwd-scoped ("most recent conversation in the current directory", includes dirs added via /add-dir).
- `--fork-session`: "When resuming, create a new session ID instead of reusing the original (use with --resume or --continue)." Without it, resume continues the same session ID. Sessions page: "If you resume the same session in two terminals without forking, messages from both interleave into one transcript." Fork resumption in `-p` plan-mode case: not restored with fork.
- `--no-session-persistence`: "Disable session persistence so sessions are not saved to disk and cannot be resumed. Print mode only." Env equivalent `CLAUDE_CODE_SKIP_PROMPT_HISTORY=1` (any mode; "do not appear in --resume, --continue, or up-arrow history").
- `--allowedTools` / `--allowed-tools`: "Tools that execute without prompting for permission, apart from reads from network paths ... To restrict which tools are available, use `--tools` instead." Examples: `--allowedTools "Bash,Read,Edit"`, `"Bash(git log *)"` (space before `*` = prefix match). Headless page: "Calls to tools you didn't list run if they need no approval. In a Manual mode `claude -p` run, a call that needs approval is denied unless something approves it, such as a PermissionRequest hook or a --permission-prompt-tool." "With Claude Code v2.1.302 or later, claude -p runs start in Manual mode when nothing sets a permission mode." Other related flags: `--permission-mode` (auto, dontAsk, acceptEdits...), `--permission-prompts none` (v2.1.259+), `--bare`, `--max-budget-usd`.
- Resume + permission mode: `claude -p --resume/--continue` starts "in the permission mode a new claude -p run would start in", except a session that ended in plan mode under specific conditions (sessions page).
- Resume + `-p` of a still-running background session: may attach / exit 1 (sessions page) - only relevant if background sessions are used.
- Resume does not restore: `--mcp-config`, `--settings`, `--plugin-dir`, `--fallback-model`, `--add-dir` (must be re-passed); settings files are re-read. System prompt is recorded on the first request and reused on resume unless compaction or `--system-prompt-snapshot off` (cli-reference).
- Piped stdin cap 10MB (headless).
- `--output-format`: options `text` (default), `json`, `stream-json` (stream-json needs `--verbose`; headless examples). Headless page: "`json`: structured JSON with result, session ID, and metadata"; extract with `jq -r '.result'` and `jq -r '.session_id'`. Documented fields of the final result object (TypeScript SDK `SDKResultMessage`, https://code.claude.com/docs/en/agent-sdk/typescript; the CLI JSON is described as this result message but a field-by-field CLI JSON schema page was not found):
  - success arm: `type:"result"`, `subtype:"success"`, `uuid`, `session_id`, `duration_ms`, `duration_api_ms`, `is_error` (boolean), `api_error_status?`, `num_turns`, `result` (string), `stop_reason`, `total_cost_usd`, `usage`, `modelUsage`, `permission_denials`, `structured_output?` (only with `--json-schema`), `terminal_reason?` (one of completed, max_turns, tool_deferred, aborted_streaming, aborted_tools, hook_stopped, stop_hook_prevented, background_requested, blocking_limit, rapid_refill_breaker, prompt_too_long, image_error, model_error, api_error, malformed_tool_use_exhausted, budget_exhausted, structured_output_retry_exhausted, tool_deferred_unavailable, turn_setup_failed), `deferred_tool_use?`, `fast_mode_state?`, `origin?` etc.
  - error arm: `subtype` one of `error_max_turns | error_during_execution | error_max_budget_usd | error_max_structured_output_retries`, with `errors: string[]` instead of `result`, plus the same session_id/cost/usage fields; `startup_failure_reason?` (e.g. `org_pin_api_key_conflict`, `provider_not_allowed`, `org_verify_failed`, `org_pin_mismatch`, `worktree_unverified`, `worktree_resume_refused`, `session_held_by_background`; set `CLAUDE_CODE_STARTUP_FAILURE_RESULTS=1` to get this result for every startup failure, "Without that variable, Claude Code writes the result only for these failures, and the rest end with stderr output, a non-zero exit, and no result message").
  - Resume + cost: "When you continue an earlier conversation with --continue or --resume, the run reports the conversation's whole total, earlier runs' spend included" (headless).
  - With stream-json: "The last line of the stream is a `result` message"; `system/init` event is first (model, tools, MCP servers, plugins, `plugin_errors`, `mcp_servers`, `capabilities`); `system/api_retry` events (fields attempt, max_retries, retry_delay_ms, error_status, error category, session_id).
- Exit codes: "Claude Code exits with code 0 on success and a non-zero code when the run fails". "If you pass an invalid flag, Claude Code reports the error to stderr before the run starts." SIGTERM -> exit 143 with no result recorded for in-flight turn (headless). Exit 1 documented for: `--resume` with unknown ID, `claude auth status` when not logged in. `--json-schema` invalid: `Error: --json-schema is not a valid JSON Schema`. Piped stdin over 10MB -> non-zero exit.
- Background-work wait: after the turn finishes a `-p` run can stay open for background tasks; `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` default 10 minutes (headless).
- `-p` sessions never prompt for workspace trust or MCP approval: "Without --bare, a -p session runs the hooks in a project's .claude/settings.json and connects the servers in its .mcp.json, even in a folder you've never trusted." Built-in terminal-only commands such as `/login` are unavailable in `-p`.

---------------------------------------------------------------------
## 5. Environment variables and network endpoints
---------------------------------------------------------------------

Sources: https://code.claude.com/docs/en/env-vars ; https://code.claude.com/docs/en/network-config ; https://code.claude.com/docs/en/data-usage ; https://code.claude.com/docs/en/setup

### Variables (verbatim/near-verbatim from env-vars table)
- `DISABLE_AUTOUPDATER`: "Set to 1 to disable automatic background updates. Manual `claude update` still works."
- `DISABLE_UPDATES`: "Set to 1 to block all updates including manual claude update and claude install."
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: "Set to any non-empty value, such as 1, to disable nonessential network traffic: auto-updates, telemetry, error reporting, the /feedback command, Claude-drafted feedback, release notes, the PR and MR status badge checks, and availability checks such as the fast mode check ... **Setting it to 0 or false still disables this traffic** ... Also disables feature-flag fetching, which makes Remote Control and the other features that need feature-flag fetching unavailable. Official plugin marketplace auto-install isn't covered; disable it with `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`."
- `DISABLE_TELEMETRY`: any non-empty value (even 0/false) opts out of telemetry; also disables feature-flag fetching. `DO_NOT_TRACK=1`: same effect (read as a normal boolean, `0` leaves telemetry on).
- `DISABLE_ERROR_REPORTING`: any non-empty value opts out of error reporting.
- `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` (the real name; `DISABLE_FEEDBACK_SURVEY` is not the table name). Surveys also disabled by DISABLE_TELEMETRY / DO_NOT_TRACK / NONESSENTIAL_TRAFFIC.
- `ENABLE_CLAUDEAI_MCP_SERVERS=false`: stop fetching claude.ai MCP connectors (enabled by default for logged-in users; also setting `disableClaudeAiConnectors`).
- `CLAUDE_CODE_DISABLE_ARTIFACT=1` / setting `enableArtifact:false`: drop the artifact-host requirement (network-config table).
- `CLAUDE_CONFIG_DIR`, `CLAUDE_CODE_PROJECT_DIR_NAME`, `CLAUDE_CODE_TMPDIR`, `CLAUDE_CODE_SKIP_PROMPT_HISTORY`, `USE_BUILTIN_RIPGREP` (0 = use system rg), `DISABLE_INSTALLATION_CHECKS`: see Q1/Q2.
- Proxy/TLS (network-config): `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY` (lowercase variants honoured; no SOCKS), `NODE_EXTRA_CA_CERTS`, `CLAUDE_CODE_CERT_STORE` (default `bundled,system`), `CLAUDE_CODE_CLIENT_CERT/KEY/KEY_PASSPHRASE`, `CLAUDE_CODE_GZIP_REQUEST_BODIES`.
- Auth env vars (present in docs; forbidden by PoC): `ANTHROPIC_API_KEY` (X-Api-Key; in -p always used when present), `ANTHROPIC_AUTH_TOKEN` (Bearer), `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`). Docs state `ANTHROPIC_API_KEY` set in the environment overrides the subscription ("When set, this key is used instead of your Claude Pro, Max ... subscription even if you are logged in. In non-interactive mode (-p), the key is always used when present").
- Flag-style note (env-vars): "These variables read only whether you set them at all, so any non-empty value including 0 turns the behavior on": `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `CLAUDE_CODE_TMUX_TRUECOLOR`, `IS_DEMO`.
- Settings.json `env` block can carry these values; "No shell processes them, so shorthand such as ~ or $HOME stays as typed."
- Streaming/timeouts relevant to long `kubectl exec` runs: `API_TIMEOUT_MS`, `CLAUDE_STREAM_IDLE_TIMEOUT_MS`, `CLAUDE_STREAM_FIRST_BYTE_TIMEOUT_MS`, `CLAUDE_ENABLE_STREAM_WATCHDOG` etc. (network-config "Streaming idle watchdogs": first-byte deadline 180 s, event watchdog 300 s on direct Anthropic API).

### Network endpoints (network-config "Network access requirements", doc as of 2026-11-01)
| Host | Purpose (per doc) |
| api.anthropic.com | Claude API requests, WebFetch domain safety check, feature flag fetches, telemetry event logging |
| claude.ai | claude.ai account authentication |
| claude.com | claude.ai sign-in opens a claude.com page in the browser which redirects to claude.ai; doc lookups |
| platform.claude.com | Console auth; "OAuth token exchange, refresh, and revocation also go to this host for claude.ai accounts, so both Console and claude.ai sign-ins require it" |
| sso.claude.com | SSO sign-in flow only |
| mcp-proxy.anthropic.com | claude.ai MCP connectors (default on for claude.ai-authenticated users) |
| downloads.claude.ai | plugin executable downloads; native installer, native auto-updater, update version checks |
| storage.googleapis.com | plugin install counts/metadata; and native installer/auto-updater on versions prior to 2.1.116 |
| registry.npmjs.org | plugin installs, npx MCP servers, and npm/bun installs of Claude Code itself |
| github.com | cloning plugin marketplaces |
| raw.githubusercontent.com | changelog for /release-notes ("non-interactive and cloud sessions never fetch it") |
| http-intake.logs.us5.datadoghq.com | operational telemetry (only when CLI uses Anthropic API directly); disable with DISABLE_TELEMETRY or DO_NOT_TRACK |
| browser-intake-us5-datadoghq.com | operational error reports; disable with DISABLE_ERROR_REPORTING or DISABLE_TELEMETRY |
| bridge.claudeusercontent.com, *.frame.claudeusercontent.com | Claude in Chrome bridge; Artifact content reads |
| formulae.brew.sh | Homebrew only |
| code.claude.com | doc lookups by claude-code-guide agent / WebFetch |
| *-review.googlesource.com | Gerrit lookup, Desktop only |
Doc statements: "The two Datadog intake hosts carry only optional operational telemetry, and setting CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC disables both." (So current docs name Datadog, not Statsig/Sentry; legacy `statsig/` dir is "No longer written".) Also: "The first-run setup connectivity check points here when it can't reach api.anthropic.com or platform.claude.com." Telemetry details page: https://code.claude.com/docs/en/data-usage#telemetry-services (section exists; not read in full).

---------------------------------------------------------------------
## Questions a planner must decide (not answered by docs)
---------------------------------------------------------------------
- Whether to pin a version (`install.sh | bash -s <version>` or npm `@version`) vs channel, and whether to set DISABLE_AUTOUPDATER vs DISABLE_UPDATES (the latter also blocks `claude update`/`claude install`).
- Whether the PVC holds only CLAUDE_CONFIG_DIR or also `~/.local/share/claude`, and whether `.claude.json` (which lives inside CLAUDE_CONFIG_DIR when it is set) is enough to skip first-run onboarding (not verified by doc).
- Whether to fix `CLAUDE_CODE_PROJECT_DIR_NAME` so transcripts are independent of the cwd used in `kubectl exec`.
- How the caller handles `claude -p` failures: parse stdout JSON `is_error`/`subtype` vs exit code; pre-check with `claude auth status` (exit 1 when not logged in).
- Behaviour of `--session-id` when the UUID already has a transcript must be established outside the docs.
- Egress allow-list for the Pod (hosts above) and whether telemetry/feature-flag traffic is blocked via DISABLE_NONESSENTIAL_TRAFFIC (which also disables feature-flag fetching).

---------------------------------------------------------------------
## Searched but NOT found
---------------------------------------------------------------------
1. A documented `--claudeai` flag for `claude auth login` (CLI reference lists only `--email`, `--sso`, `--console`).
2. Minimum glibc version for the Linux binary; explicit statement that git is/is not a Linux runtime dependency.
3. Doc statement of what happens to native auto-update when `~/.local/bin` / `~/.local/share/claude` is read-only (only generic "Auto-update failed" footer + `claude doctor`).
4. Names of keys in `.claude.json` governing onboarding/login state (e.g. hasCompletedOnboarding, oauthAccount) - not on claude-directory, authentication, or env-vars pages (settings-reference#global-config-settings was linked but not fetched).
5. Exact OAuth access-token lifetime / refresh-token lifetime for subscription login.
6. Behaviour when `--session-id <uuid>` refers to an existing session (error vs append vs overwrite) - no doc text found in cli-reference, headless, sessions, errors, or SDK reference.
7. Exact stdout JSON and exit code of `claude -p --output-format json` when not logged in (docs only say failure is "printed as the result on stdout" and non-zero exit; messages `Not logged in · Please run /login` and `Failed to authenticate: OAuth session expired and could not be refreshed` with code `authentication_failed`).
8. Whether `No conversation found with session ID` is emitted as JSON under `--output-format json` (docs show stderr-style text and exit 1 for `claude --resume`).
9. A dedicated CLI-JSON schema page for `claude -p --output-format json` (field list above is from the Agent SDK `SDKResultMessage` reference).
10. Full read of the devcontainer persistence page (https://code.claude.com/docs/en/devcontainer.md) and the data-usage telemetry section details; not fetched in full. Remaining ~490k chars of the errors page were not fully read (targeted sections only).
11. GitHub repo/changelog (anthropics/claude-code CHANGELOG) was not consulted for per-version behaviour; docs state version minimums inline.

---

# Claude Code managed settings, deny rules, headless -p: research findings

Fetched 2026-11-01 from code.claude.com (docs are versionless "current"; version gates quoted inline, latest version numbers seen in docs ~v2.1.302). Facts only. Every URL below is under https://code.claude.com/docs/en/.

## Q1. Managed settings path, mechanisms, precedence, drop-ins, symlinks

Sources: managed-settings (https://code.claude.com/docs/en/managed-settings.md), settings (.../settings.md), debug-your-config.

- Linux path: "**Linux and WSL**: `/etc/claude-code/managed-settings.json`" (managed-settings.md, "Deploy a managed settings file"). File-based set: "`managed-settings.json`, an optional `managed-settings.d/` directory, and `managed-mcp.json` in the system directory: `/Library/Application Support/ClaudeCode/` on macOS, `/etc/claude-code/` on Linux and WSL, and `C:\Program Files\ClaudeCode\` on Windows." So yes, current.
- Managed mechanisms: (1) server-managed settings (claude.ai console, or self-hosted Claude apps gateway); (2) MDM/OS: macOS plist domain `com.anthropic.claudecode`, Windows HKLM `SOFTWARE\Policies\ClaudeCode` value `Settings`; (3) file-based (above); (4) Windows HKCU registry (user-writable fallback); (5) embedding-host "parent settings"; (6) `policyHelper` (settings-reference). Source: managed-settings.md "Where each mechanism stores the policy" and "How Claude Code combines managed sources".
- Managed-source order (highest first): 1 remote settings (fetched only when session authenticates to Anthropic API directly with eligible credential / gateway; "On other providers, or when ANTHROPIC_BASE_URL points somewhere other than Anthropic's API, it starts at the next source"), 2 MDM/OS, 3 managed files (`managed-settings.d/*.json` + `managed-settings.json` merged), 4 HKCU. Default `managedSourcesBehavior: "first-wins"` (highest source delivering a policy key wins, others ignored with no warning); `"merge"` needs v2.1.242+.
- Overall precedence (settings.md "Settings precedence"), highest first: Managed; Command line (`--settings`); Project local `.claude/settings.local.json`; Shared project `.claude/settings.json`; User `~/.claude/settings.json`. Quote: "Nothing in your own settings files or `--settings` overrides a managed key". Env vars are not a level; decided per pair. Lists (e.g. permissions.allow) merge across files. A few keys honor a stricter lower-scope value (table "Exceptions to managed settings precedence", e.g. `permissions.blockReadsOutsideWorkingDirectories: true` from any scope, v2.1.257+).
- Drop-in dir: yes. "Claude Code merges `managed-settings.json` first, then every `*.json` file in the directory in alphabetical order... Claude Code ignores hidden files and files that don't end in `.json`." Merge rules: single values later wins; lists combine, dedup; nested blocks (env, sandbox) merge key by key.
- Symlinks: "You can deploy any of these files as a symbolic link, and Claude Code reads the file the link leads to. The policy still applies when the link leads outside the system directory or Claude Code can't confirm that it stays inside. A warning naming the file then appears in `/status` and `claude doctor`. To clear the warning, point the link at a target inside the system directory." (managed-settings.md, file-based bullet). Caveat is only a warning. The docs do not mention Kubernetes, ConfigMaps or subPath (searched; not found).
- Unreadable/invalid: file present but not valid JSON object -> "Claude Code refuses to start and prints an error"; empty file counts as `{}`; absent file is not a failure; if OS denies read (e.g. root-only file) "every session starts without that source's policies... a run with -p also prints it to stderr"; other read failures -> exits at startup. A file containing only control keys (`wslInheritsWindowsSettings`, `managedSourcesBehavior`) is not a "policy key" and is skipped. Invalid individual entries are dropped with a warning (stderr in -p); some keys "fail closed" (e.g. forceLoginOrgUUID: "No organization is permitted to log in until the value is fixed.").
- Changes at runtime: settings.md "When edits take effect": file watchers reload user/project/local/managed settings files; MDM/console sources arrive on a schedule per delivery table.
- Login keys source rule (managed-settings.md "Which managed source supplies login keys"): on a machine with MDM policy or managed file, login keys come from that policy/file even if remote settings also set them; if both MDM and file exist and MDM sets any policy key, login keys in the file are ignored.

## Q2. Keys and semantics (settings-reference.md, authentication.md "Restrict login to your organization")

- `forceLoginMethod`: type string, `"claudeai"` | `"console"` | `"gateway"`; default unset. "Set `"claudeai"` to allow only claude.ai accounts, `"console"` to allow only Claude Console accounts". Scope "Any file"; `"gateway"` honored only from same sources as forceLoginGatewayUrl. Setting `"claudeai"` in any file also stops offering keyless Console sign-in. Since v2.1.212 every login path applies it "except the terminal's interactive login screen, reached by `/login` or first-run onboarding, which pre-selects the method without enforcing it" (so `claude auth login` interactive screen may still allow Console; docs list `claude auth login --console`/`--sso` flags in cli-reference).
- `forceLoginOrgUUID`: type "string, one UUID, or array of strings, several UUIDs"; default unset. "From a managed source, require claude.ai account logins to belong to one Anthropic organization, given as a single UUID, or to any of several organizations, given as an array... Only a managed source enforces the restriction; a single UUID in any other settings file pre-selects the organization during login without restricting it." Mismatch: authentication.md: "Claude Code reports an error for a claude.ai login to any other organization and exits at startup if the claude.ai credential in use belongs to an organization that isn't listed." Invalid: "If a managed source sets an empty array, or a value that isn't a string or an array of strings, users who sign in with an Anthropic account can't start Claude Code or complete a login. They see a message that names `forceLoginOrgUUID`" (also fail-closed table in managed-settings.md). Docs do NOT state behavior for a string that is a well-formed but nonexistent/placeholder UUID beyond the "belongs to an organization that isn't listed" rule (not found as a separate case). Console logins: "It doesn't check which organization the resulting Console credential belongs to, at login or at startup." `claude setup-token` and `/install-github-app` enforce only forceLoginMethod. Setting the key in any file also stops keyless Console sign-in and creates an API key.
- Interaction with API-key credentials: `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, or `apiKeyHelper` are "blocked at startup" when forceLoginOrgUUID/forceLoginMethod are set ("organization membership can't be verified for an environment credential") (authentication.md). Cloud-provider sessions (Bedrock etc.) blocked only while such a credential is present.
- Remote-settings fallback: "if the policy or file omits either key, the value in remote settings applies" (v2.1.299+ behavior note).
- `permissions.disableBypassPermissionsMode`: type string `"disable"`, scope Any file (typically managed); makes Claude Code reject `--dangerously-skip-permissions`. Also `permissions.disableAutoMode: "disable"` (permission-modes.md).
- `allowManagedPermissionRulesOnly`: scope Managed. "Claude Code then ignores `allow`, `ask`, and `deny` rules in user, project, local, and `--settings` files, ignores `--allowedTools`, hides the always-allow choices... `--disallowedTools` rules and the current session's `deny` and `ask` rules still apply" (settings-reference, truncated by fetch; entry also in permissions.md).
- `apiKeyHelper`: string shell command line, scope Any file; output sent as X-Api-Key and Authorization: Bearer. Blocked at startup if forceLogin* keys set (see above).
- `env`: "Set environment variables for every session and its subprocesses", scope Any file; ordinary key, follows precedence levels; telemetry export vars ignored from project/local; a managed env vs shell export is decided per the `env` entry (not read in detail).
- Auto-update: `autoUpdatesChannel` (`"latest"`|`"stable"`, any file, enforce via managed). Env var `DISABLE_AUTOUPDATER`: "Set to `1` to disable automatic background updates. Manual `claude update` still works. Use `DISABLE_UPDATES` to block both" (env-vars.md). A settings key literally named `autoUpdates` was searched in settings-reference and not found.
- Other relevant managed-only/related keys seen: `allowedProviders` (v2.1.285+), `requiredMinimumVersion`, `managedSourcesBehavior`, `policyHelper`.

## Q3. permissions.deny syntax and limits (permissions.md)

- Evaluation: "Rules are evaluated in order: deny, then ask, then allow. The first match... An allow rule can't carve an exception out of a deny rule." Bare tool name deny (e.g. `Bash`) removes the tool from Claude's context; scoped rule leaves tool available and blocks matching calls.
- Read/Edit pattern types (gitignore syntax): `//path` = absolute from filesystem root (`Read(//Users/alice/secrets/**)`); `~/path` = from home (`Read(~/Documents/*.pdf)`); `/path` = relative to the settings source ("anchors at the settings source, not the filesystem root. Use `//Users/alice/file` for absolute paths"; in user settings `Read(/secrets/**)` blocks `~/.claude/secrets/**`); `path` or `./path` = relative to cwd. Bare filenames match at any depth (`Read(.env)` == `Read(**/.env)`). Deny/ask `Read(secrets/**)` matches at any depth.
- Applicable forms for credentials file (derived from the table; no doc example of .credentials.json): `Read(~/.claude/.credentials.json)` or `Read(//home/<user>/.claude/.credentials.json)`. For `$CLAUDE_CONFIG_DIR`, no env-var expansion in rule syntax is documented (searched; not found), so an absolute `//path` or `~/` form matching the actual dir would be needed. authentication.md: Linux creds at `~/.claude/.credentials.json` mode 0600; with CLAUDE_CONFIG_DIR set the file lives under that directory.
- Grep/Glob: "Claude makes a best-effort attempt to apply `Read` rules to all built-in tools that read files like Grep and Glob, to `@file` mentions..." Grep/Glob "search the directory the `path` argument resolves to. Claude Code applies `Read` deny rules to that directory." `Glob(path)`/`Write`/`NotebookEdit` path rules "never match"; use `Read(...)`/`Edit(...)`. `Read` deny also blocks Edit/Write on that path.
- Symlinks: deny rules "apply when either the requested path or the file it resolves to matches."
- Bash: "Read and Edit deny rules apply to Claude's built-in file tools, to file commands Claude Code recognizes in Bash, such as `cat`, `head`, `tail`, `sed`, and `tee`, and to the targets of Bash redirections such as `> file` and `< file`. They don't apply to a command that reads files without naming them, such as `grep -r pattern .` run from the directory that holds the file, or to arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself. For OS-level enforcement that blocks all processes from accessing a path, enable the sandbox." So Read deny does cover recognized `cat <file>`, but not all Bash paths.
- Bash rule limits: wrappers stripped (`timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob`, bare `xargs`); "A deny rule doesn't match the same program by path or inside `sh -c`" (see anchor #bash-rule-limits). Built-in read-only Bash set (`ls cat echo head tail grep find wc ...`) runs without prompt "in every mode"; "to require a prompt for one of these commands, add an `ask` or `deny` rule". Alternatives named: sandboxing ("filesystem and network enforcement that doesn't depend on the command text"), PreToolUse hook. Permissions and sandbox are "complementary"; sandbox applies to Bash/PowerShell/Monitor and children only.
- `.claudeignore` "has no effect". `Bash(command:...)`-style primary-field rules are ignored with warning.

## Q4. --allowedTools in -p mode (headless.md, cli-reference.md, permission-modes.md)

- cli-reference: "`--allowedTools`: Tools that execute without prompting for permission, apart from reads from network paths... To restrict which tools are available, use `--tools` instead." `--disallowedTools` = deny rules. `--permission-mode` accepts default/acceptEdits/plan/auto/dontAsk/bypassPermissions/manual.
- headless.md: "Calls to tools you didn't list run if they need no approval. In a Manual mode `claude -p` run, a call that needs approval is denied unless something approves it, such as a PermissionRequest hook or a --permission-prompt-tool. With Claude Code v2.1.302 or later, `claude -p` runs start in Manual mode when nothing sets a permission mode." So `--allowedTools` is an auto-approve list, not a restriction: tools not listed still run if they need no approval (permissions.md: file reads/Grep within working dir need no approval; read-only Bash set needs none). Tools needing approval and not allowed are denied (no prompt in -p).
- Read/Grep/Glob need no extra flag for reads inside working dirs/additional dirs (permissions.md table: "Read-only: File reads, Grep - No, within the working directory and additional directories"). Reads outside working dirs need approval (allow rule) unless blocked via `permissions.blockReadsOutsideWorkingDirectories`. `--allowedTools Read` auto-approves Read "apart from reads from network paths".
- `--permission-mode dontAsk`: denies everything that would prompt; reads in working dirs and `--allowedTools`/allow-rule tools still run (headless.md). Docs example for exact allowlist in CI: `--permission-mode dontAsk --allowedTools "Bash(npm test)" "Read"` (permission-modes.md). For older versions than v2.1.302 default `-p` behavior: see permission-modes.md "Tool calls denied in claude -p" (not fully read).
- Deny precedence: deny beats allow, so `--allowedTools Read` cannot override a `Read(...)` deny rule (permissions.md). With `allowManagedPermissionRulesOnly`, `--allowedTools` is ignored.
- JSON output: `--output-format json` gives result, session ID, metadata, cost (headless.md). The result message type has `permission_denials: SDKPermissionDenial[]` with `{tool_name, tool_use_id, tool_input}` (agent-sdk/typescript.md, SDKResultMessage / SDKPermissionDenial). headless.md: "With `--output-format stream-json`, denials appear as `permission_denied` system messages, and the final result message lists them in `permission_denials`" (in the `--permission-prompts none` section; flag needs v2.1.259+). agent-sdk/typescript.md: the permission_denied event "skips any denial decided on the PreToolUse hook path, whether the hook denied the call itself or a deny rule overrode the hook's allow or ask decision... best-effort... `permission_denials` on the result message is the authoritative record." Whether a deny-rule denial specifically appears in plain `--output-format json` `permission_denials` was not stated explicitly for the CLI json format (not found as an explicit statement; SDK type defines the field).
- Missing auth under -p: "When a failure happens inside the run, such as missing authentication, Claude Code prints the failure as the result on stdout"; exit non-zero on failure.
- `--bare` -p mode: never reads OAuth credentials or keychain; needs ANTHROPIC_API_KEY or apiKeyHelper (incompatible with subscription login by design). `--restricted` flag exists: loads only managed settings and --settings, removes command-running tools, confines file tools to working dirs (cli-reference; partly read).
- Settings loading in -p: project hooks/MCP from `.claude/settings.json` run in -p even in untrusted folders unless `--bare`.

## Q5. Checking effective managed settings

- Interactive: `/status` -> `Setting sources` line lists loaded sources, e.g. `Enterprise managed settings (file)`, `(drop-ins)`, `(file + drop-ins)`, `(remote)`, `(plist)`, `(HKLM)`; second line `Skipped sources` (v2.1.242+). "The line is missing: Claude Code found no managed source that delivers a policy key." Also shows symlink warnings. It does not show which file supplied each key (settings.md "Confirm what loaded"). `/config` Config tab is not a view of settings.json contents.
- Headless: `claude doctor` (CLI command, run from terminal, no session): "Print read-only installation and settings diagnostics... including install health, settings-file validation errors" (cli-reference); lists each invalid entry with source and field; reports server-managed fetch outcome; shows symlink warning (managed-settings.md). `-p` prints invalid managed entries summary to stderr. `claude auth status` prints JSON (`authMethod`, `configDirectory` v2.1.268+; exit 0 logged in / 1 not). `/status` is described for interactive sessions; docs (headless.md) list supported slash commands in -p (/model, /effort, /fast, /color, /rename, /mcp, /config key=value, /output-style); `/status` and `/doctor` availability in -p not stated (not found). `/context`, `/doctor`, `/hooks`, `/mcp` are the interactive inspectors (debug-your-config.md).
- Stream-json `system/init` event reports model, tools, MCP servers, plugins (headless.md "Read session metadata"); no documented field for managed settings or permission rules (not found).

## Questions for the planner (not answered by docs)
- ConfigMap mounts are symlink chains into `..data`; docs allow symlinks but warn (in /status and doctor) when target is outside `/etc/claude-code/` or can't be confirmed inside; ConfigMap targets (`..data/...`) are inside the dir, so whether a warning appears is not documented. subPath avoids symlink but loses ConfigMap live update (Kubernetes behavior, not Claude docs).
- Pod runs without Anthropic first-party direct connection? Remote settings only fetched on direct API auth; file is the fallback.
- Which user's HOME / CLAUDE_CONFIG_DIR will hold `.credentials.json`, and how to express it as `//abs` or `~/` in a deny rule (no env expansion documented).
- Read deny does not cover non-recognized Bash reads; sandbox (needs OS support in container) or tool restriction (`--tools`, `--disallowedTools Bash`) are the documented alternatives.
- Placeholder `forceLoginOrgUUID`: documented fail-closed only for wrong type/empty array; behavior for a syntactically valid but non-matching UUID is "login error / exit at startup" per authentication.md.

## Searched but not found
- Any Kubernetes/ConfigMap/subPath/container-specific guidance for managed-settings.json.
- Environment-variable expansion (`$CLAUDE_CONFIG_DIR`) inside permission rule paths.
- A settings key named `autoUpdates` (only `autoUpdatesChannel` and env `DISABLE_AUTOUPDATER`/`DISABLE_UPDATES`).
- Explicit statement of how forceLoginOrgUUID treats a well-formed placeholder UUID at runtime other than the generic "isn't listed" error.
- Explicit doc of deny-rule denials in plain `--output-format json` output (field exists in SDK result type).
- Documented `claude -p "/status"` output of managed sources.
- Did not run GitHub changelog/repo search; findings are from the official docs only.

## Source list
managed-settings.md, settings.md, settings-reference.md, permissions.md, permission-modes.md, headless.md, cli-reference.md, authentication.md, env-vars.md, debug-your-config.md, agent-sdk/typescript.md (all https://code.claude.com/docs/en/<page>).

---

# Kubernetes / GKE facts for a per-person Claude Code Pod PoC

Research date: 2026-11-01. Facts only, no recommendations. Pages were read through a summarizing fetch tool, so quotes are as returned by that tool; items marked UNVERIFIED are not confirmed by a fetched source. GKE docs "last updated" dates are given per source (all 2026-10-26 to 2026-10-31).

---
## Q1. kubectl exec

Sources: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_exec/ ; https://raw.githubusercontent.com/kubernetes/kubectl/master/pkg/cmd/exec/exec.go ; https://kubernetes.io/releases/ ; https://github.com/kubernetes/kubernetes/issues/30656

- Latest releases (kubernetes.io/releases, page dated 2026-09-15): 1.37.1, 1.36.5, 1.35.9, 1.34.12 (1.34 EOL 2026-10-27). kubectl skew policy not on that page (links to https://kubernetes.io/releases/version-skew-policy/; the "within one minor version" statement is general knowledge, UNVERIFIED here).
- Synopsis: `kubectl exec (POD | TYPE/NAME) [-c CONTAINER] [flags] -- COMMAND [args...]`
- Flags listed: `-c/--container`, `-f/--filename`, `-h`, `--pod-running-timeout` (default 1m0s), `-q/--quiet`, `-i/--stdin`, `-t/--tty`. Global: `-n`, `--context`, `--kubeconfig`, `--request-timeout` (default 0 = no timeout), etc.
- Workdir: no `--workdir`/`-w` flag is listed on the reference page for any flag set seen; exec.go shows the request sets only container, command, stdin/stdout/stderr, TTY. Documented workaround form from the fetch: `kubectl exec mypod -- sh -c 'cd /app && ls'`. Search found no dedicated kubectl workdir feature request (only #30656 "Support the user flag from docker exec in kubectl exec", long open then closed). Only the current (master/1.36/1.37) reference was checked; older versions not individually checked.
- Container WORKDIR: the exec request carries no working-directory field (exec.go), and the docs do not state which directory the exec'd process starts in. Whether it equals image WORKDIR is NOT confirmed by a fetched source.
- `--` separator: "Everything after `--` is passed to the container as the command and its arguments. Use `--` when the command has flags in common with kubectl (e.g., `-i`, `-t`)." "Don't wrap the command in quotes unless you would do so in a normal shell."
- Container selection: `-c` value, else annotation `kubectl.kubernetes.io/default-container`, else first container.
- Pod addressing: StatefulSet pods are named `$(statefulset name)-$(ordinal)` (e.g. web-0) (https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/). Page example also shows `kubectl exec deploy/NAME` and `svc/NAME` forms; a statefulset/NAME form is not shown on the page.
- TTY / stderr (exec.go): if stdin not attached, `o.TTY = false`. If -i without a terminal: TTY disabled and "Unable to use a TTY - input is not a terminal or the right kind of file" printed unless --quiet. `t.Raw` is true only when stdin attached + TTY wanted + stdin is a terminal. Code comment: "unset p.Err if it was previously set because both stdout and stderr go over p.Out when tty is true" (`p.ErrOut = nil`). So with a real TTY, stderr and stdout are one stream; without -t they are separate streams. Issue https://github.com/kubernetes/kubectl/issues/1579 reports -t merging stdout/stderr by design.
- Added `\r` with TTY: not confirmed by a fetched source (UNVERIFIED; general PTY behavior).
- Exit code: exec.go itself contains no exit-code handling; handled in the remotecommand executor (client-go). The phrase "command terminated with exit code" and non-zero kubectl exit propagation were NOT confirmed by a fetched source (reference page says exit codes are not documented). UNVERIFIED.
- Timeouts: `--request-timeout` default 0 (no timeout). `--pod-running-timeout` default 60s (exec.go `defaultPodExecTimeout = 60 * time.Second`) only waits for pod running. Search results (secondary): kubelet `streamingConnectionIdleTimeout` governs idle exec streams; Platform9 KB https://platform9.com/kb/kubernetes/kubectl-exec-is-timed-out-after-4-hours reports exactly-4-hour cutoffs when kubelet value is unset/default; Trend Micro CIS GKE note says the default is 4 hours; k8s PR #81179 (`--ping-interval` keepalive proposal, closed). A Codemia page says `--request-timeout` limits only client-to-API-server, not command runtime. No GKE-specific doc on exec duration limits was found; intermediate L4/proxy idle limits (GKE control plane endpoint) not documented in anything fetched.

## Q2. StatefulSet storage, PVC, GKE storage

Sources: StatefulSet doc (https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/); https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes (upd. 2026-10-30) ; https://docs.cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver (upd. 2026-10-30) ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/storage-overview ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/autopilot-resource-requests

- PVC per pod: "For each VolumeClaimTemplate entry defined in a StatefulSet, each Pod receives one PersistentVolumeClaim ... If no StorageClass is specified, then the default StorageClass will be used."
- PVC name pattern: not in fetched text. (General knowledge, UNVERIFIED here: `<template-name>-<statefulset-name>-<ordinal>`.)
- Retention: "Deleting and/or scaling a StatefulSet down will not delete the volumes"; "PersistentVolumes associated with the Pods' PersistentVolume Claims are not deleted when the Pods, or StatefulSet are deleted. This must be done manually." `.spec.persistentVolumeClaimRetentionPolicy` with `whenDeleted` and `whenScaled`, values `Retain` (default) or `Delete`; page says it needs the `StatefulSetAutoDeletePVC` feature gate (feature-gate status per GKE version not checked). Deleting a Pod (e.g., reschedule) re-mounts the same PVC for the same ordinal.
- fsGroup: "all processes of the container are also part of the supplementary group ID 2000. The owner for volume /data/demo and any files created in that volume will be Group ID 2000." `fsGroupChangePolicy`: `OnRootMismatch` ("Only change permissions and ownership if the permission and the ownership of root directory does not match") or `Always` ("Always change permission and ownership of the volume when volume is mounted"); by default "Kubernetes recursively changes ownership and permissions for the contents of each volume to match the fsGroup". No effect on ephemeral types (secret, configMap, emptyDir). If a CSI driver supports `VOLUME_MOUNT_GROUP`, the driver applies fsGroup and `fsGroupChangePolicy` does not take effect (Stable since v1.26). Whether GKE PD CSI supports VOLUME_MOUNT_GROUP: NOT found in fetched GKE pages.
- GKE default StorageClass:
  - persistent-volumes concept page: "GKE creates a default StorageClass for you which uses the balanced persistent disk type (ext4)." Recommends `WaitForFirstConsumer` ("provision a persistent disk in the same zone that the Pod gets scheduled to"). `Delete` reclaim policy "is the default policy" in Kubernetes terms; page does not state the default SC's reclaimPolicy.
  - gce-pd-csi-driver page: GKE installs `standard-rwo` (balanced PD) and `premium-rwo` (SSD PD). "For Autopilot clusters, the default StorageClass is standard-rwo." "In the pre-installed StorageClass (standard-rwo), volumeBindingMode is set to WaitForFirstConsumer." Fetch summary also reported "For Standard clusters, the default StorageClass uses the Kubernetes in-tree gcePersistentDisk volume plugin" (this conflicts with the concept page and with the 'balanced' statement; treat as needing direct check on the cluster, e.g. a read-only `kubectl get storageclass`).
  - storage-overview: Persistent Disk supported on Autopilot and Standard; "Balanced PD is the default for dynamic provisioning on GKE 1.24 and later."
  - reclaimPolicy of standard-rwo, allowVolumeExpansion: not confirmed in fetched text.
- Zonal PD: "Zonal persistent disks are zonal resources"; GKE assigns a single zone (random unless specified); with WaitForFirstConsumer the disk is created in the Pod's zone. Regional PDs "replicate data between two zones." Implication stated by the zonal nature: a pod using a zonal PD can be scheduled only in that disk's zone (the explicit sentence about rescheduling was not fetched; it is the zonal-resource definition above).
- Autopilot vs Standard: Autopilot always has PD CSI driver enabled and it cannot be disabled/edited. Autopilot: "Ephemeral storage limits must always be explicitly set equal to requests" (GKE modifies Pods). Autopilot defaults when unspecified (general-purpose): 0.5 vCPU, 2 GiB memory, ephemeral storage 1 GiB; min CPU 50m (bursting-capable clusters) else 250m; CPU:memory ratio between 1:1 and 1:6.5; equal requests/limits => Guaranteed QoS; requests set, limits unset => bursting allowed on bursting-capable clusters else limits = requests. Custom Autopilot StorageClasses need `use-allowed-disk-topology: "true"` in some cases (Pods with newer machine series and legacy disks like pd-standard can stay Pending).

## Q3. Pod securityContext

Sources: https://kubernetes.io/docs/concepts/security/pod-security-standards/ ; https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security (upd. 2026-10-30)

- PSS Restricted (inherits Baseline): volumes limited to configMap, csi, downwardAPI, emptyDir, ephemeral, persistentVolumeClaim, projected, secret; `allowPrivilegeEscalation` must be `false`; `runAsNonRoot` must be `true` (container fields may be nil if pod-level set); `runAsUser` must not be 0 ("any non-zero value" or undefined); `seccompProfile.type` must be `RuntimeDefault` or `Localhost` ("Both the Unconfined profile and the absence of a profile are prohibited"); capabilities: must drop `ALL`, may add back only `NET_BIND_SERVICE`.
- allowPrivilegeEscalation defaults to true if undefined; it sets `no_new_privs` inverted; `false` is inconsistent with privileged or CAP_SYS_ADMIN.
- readOnlyRootFilesystem: "Mounts the container's root filesystem as read-only." Not part of PSS Restricted per the fetched table. Effects on writable paths (e.g. /tmp, home) not documented in fetched text; only mounted volumes remain writable.
- runAsNonRoot with named USER: kubelet error "container has runAsNonRoot and image has non-numeric user (X), cannot verify user is non-root" (container ends CreateContainerConfigError). Sources (secondary): https://github.com/kubernetes/kubernetes/pull/56503 , https://www.ibm.com/support/pages/node/7047655 , https://github.com/tarantool/tarantool-operator/issues/83 . Fixes cited there: numeric `USER` in Dockerfile or numeric non-zero `runAsUser` in the pod spec. Also a user literally named `root` triggers it (stackgres issue #1646).
- GKE Autopilot (autopilot-security): "GKE strictly enforces all of the measures on this page by default" in Autopilot. Privileged containers not allowed (partners excepted). Capabilities allowed by default: SETPCAP, MKNOD, AUDIT_WRITE, CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, SETGID, SETUID, NET_BIND_SERVICE, SYS_CHROOT, SETFCAP, SYS_PTRACE; CAP_NET_ADMIN and CAP_NET_RAW dropped. "Autopilot allows running as root to enable most workloads" (runAsUser 0 allowed). "Autopilot applies the RuntimeDefault seccomp profile to all workloads" (overridable with Unconfined). hostPath: read-only /var/log only. Host networking blocked. Allowed volume types: configMap, csi, downwardAPI, emptyDir, gcePersistentDisk, nfs, persistentVolumeClaim, projected, secret. The term "warden" and its specific constraint messages were not found in fetched pages.
- GKE Standard PSS enforcement: not found in fetched pages (no default enforcement statement fetched).

## Q4. ConfigMap volume

Sources: https://kubernetes.io/docs/concepts/storage/volumes/ ; https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/

- "A ConfigMap is always mounted as readOnly." "A container using a ConfigMap as a subPath volume mount will not receive updates when the ConfigMap changes."
- Non-subPath mounts update: "total delay ... can be as long as kubelet sync period (1 minute by default) + TTL of ConfigMaps cache (1 minute by default)".
- Referencing a missing ConfigMap or key without `optional` => Pod won't start. ConfigMap must be in the Pod's namespace.
- `items: [{key, path}]` selects keys; page example mounts key `log_level` at `/etc/config/log_level.conf` ("path is derived from the volume's mountPath and the path"). So a ConfigMap key named `managed-settings.json` mounted as a whole directory at `/etc/claude-code` yields `/etc/claude-code/managed-settings.json`; a subPath mount of a single key onto `/etc/claude-code/managed-settings.json` gives that exact file but no live updates (both follow from the above statements; not shown verbatim as an example).
- `..data` symlink layout and `defaultMode`: NOT confirmed in the fetched text (general knowledge only, UNVERIFIED). The fsGroup page states fsGroupChangePolicy has no effect on configMap volumes.
- Text data is UTF-8; use `binaryData` for other encodings. Whole-directory mount at /etc/claude-code would hide any existing image files in that directory (general mount behavior, UNVERIFIED in fetched docs).

## Q5. NetworkPolicy on GKE

Sources: https://docs.cloud.google.com/kubernetes-engine/docs/how-to/network-policy (upd. 2026-10-26) ; https://docs.cloud.google.com/kubernetes-engine/docs/how-to/fqdn-network-policies (upd. 2026-10-26) ; https://docs.cloud.google.com/kubernetes-engine/docs/how-to/nodelocal-dns-cache (upd. 2026-10-26)

- Enforcement: "GKE Dataplane V2 is the recommended network plugin for all clusters and is default for Autopilot clusters." "If no network plugin is configured, network policies aren't enforced." Enforcement cannot be disabled on Autopilot or Dataplane V2 clusters. Calico is Standard only and mutually exclusive with Dataplane V2. Standard: for Calico via gcloud must enable both the add-on and node enforcement; enabling re-creates nodes. Whether Standard clusters are Dataplane V2 by default: not stated on that page.
- Standard NetworkPolicy has no FQDN selector (core API: ipBlock, podSelector, namespaceSelector) — general knowledge; GKE FQDN page says use `ipBlock` of a standard NetworkPolicy for hard-coded IPs.
- GKE FQDN option: `FQDNNetworkPolicy` CRD, `apiVersion: networking.gke.io/v1alpha1`, `kind: FQDNNetworkPolicy`, `spec.podSelector`, `spec.egress[].matches[]` with `name:` or `pattern:` (e.g. "*.yourdomain.com"), `ports`. Requirements: Dataplane V2; gcloud CLI 462.0.0+. DNS provider must be kube-dns or Cloud DNS (custom kube-dns/CoreDNS unsupported). Autopilot supported but only enabled by updating an existing Autopilot cluster; nodes restart (up to a few hours). Limits: wildcard matches one subdomain level; max 50 IPs per policy and 100 per hostname; cannot allow egress to ClusterIP/Headless Service; no Windows pools, no Cloud Service Mesh, no inter-node transparent encryption. Doc states "v1alpha1" API version; GA status not stated.
- Other FQDN-capable options (Cloud NAT, firewall FQDN rules, Secure Web Proxy, Cloud Armor): searched only indirectly; no fetched page covers them. Not verified.
- DNS egress: NodeLocal DNSCache is enabled by default and not disableable on Autopilot. node-local-dns Pods use the `kube-dns-upstream` Service to reach kube-dns. "Use an ipBlock rule ... to allow communication between your Pods and kube-dns" applies when not using Cloud DNS or Dataplane V2. With Cloud DNS, Pods use name server `169.254.20.10`. On Dataplane V2 (without Cloud DNS) node-local-dns pods don't use hostNetwork. Network-policy page: pods need egress to the metadata server if Workload Identity is used; policies must allow load balancer health check ranges. No Google doc was found confirming an exact egress rule for Dataplane V2 + NodeLocal DNS; a community PR (https://github.com/tektoncd/operator/pull/4001, open) proposes ipBlock 169.254.20.10/32 and 169.254.169.254/32 (not Google guidance).

## Q6. Local prerequisites

Sources: https://docs.cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl (upd. 2026-10-30) ; https://docs.cloud.google.com/kubernetes-engine/docs/how-to/api-server-authentication

- "You must install this plugin [gke-gcloud-auth-plugin] to use kubectl and other clients to interact with GKE."
- Install: `gcloud components install gke-gcloud-auth-plugin` (apt: `google-cloud-cli-gke-gcloud-auth-plugin`; yum same name). kubectl: `gcloud components install kubectl`. Verify: `gke-gcloud-auth-plugin --version`, `kubectl version --client`. Homebrew is not mentioned on the page; USE_GKE_GCLOUD_AUTH_PLUGIN not mentioned; kubectl skew not discussed.
- Credentials: `gcloud container clusters get-credentials CLUSTER_NAME --location=CONTROL_PLANE_LOCATION` (sets current context); variants `--internal-ip`, `--dns-endpoint`. Verify with `kubectl get namespaces`.
- Mode check (read-only): `gcloud container clusters describe CLUSTER_NAME --location=LOCATION --format="value(autopilot.enabled)"` -> `True` for Autopilot, empty for Standard (from a web search summary and community write-up https://fabianlee.org/?p=2935 ; the Google page URL I tried for this returned 404). Full `describe` YAML also has an `autopilot:` block. Node pool listing (Standard): `gcloud container node-pools list` — command existence not verified via a fetched page. kubectl-side detection: not found in a fetched source.

## Q7. Image build / registry / architecture

Sources: https://docs.cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling (upd. 2026-10-26) ; https://docs.cloud.google.com/artifact-registry/docs/access-control (upd. 2026-10-26) ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/arm-on-gke (upd. 2026-10-30) ; https://docs.cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview (upd. 2026-10-31) ; https://docs.docker.com/build/building/multi-platform/

- Path: `LOCATION-docker.pkg.dev/PROJECT-ID/REPOSITORY/IMAGE[:tag]`. Repository must exist first. Auth: `gcloud auth configure-docker LOCATION-docker.pkg.dev` ("Artifact Registry does not automatically add all registry hosts to the Docker configuration file"). Push needs at least `roles/artifactregistry.writer`.
- Node pull auth: GKE nodes pull from Artifact Registry in the same project with no extra config when running as the default Compute Engine SA with storage read access (default scopes or cloud-platform). Autopilot clusters use the Compute Engine default SA if none specified (access-scopes page). Reader role is not tied to this case on that page; custom node SA case not covered.
- Architecture: "By default, workloads use the x86 architecture" (Autopilot overview). Arm: Autopilot via `autopilot-arm` ComputeClass (limited to seven regions); Standard Arm machine series listed: C4A, N4A, T2A. Multi-arch images let one manifest run on mixed nodes; node selectors/affinity recommended. Taint `kubernetes.io/arch=arm64`: not found on the page.
- Apple Silicon build: `docker buildx build --platform linux/amd64 ...`; Docker Desktop supports multi-platform builds under QEMU emulation by default (slow for compute-heavy work); alternatives: native nodes, cross-compilation (`--platform=$BUILDPLATFORM`, TARGETARCH). The page does not mention Apple Silicon specifically.

---
## Searched but not found / unverified
- Official statement of kubectl exec exit-code propagation and the "command terminated with exit code N" message.
- Any statement on the starting directory of exec'd processes (image WORKDIR vs `/`).
- `\r` insertion behavior with `-t` (only the stdout/stderr merge was confirmed).
- GKE-specific doc on exec/stream duration limits or control-plane idle timeouts.
- StatefulSet PVC name pattern text; `..data` symlink and ConfigMap `defaultMode` text in kubernetes.io pages.
- Whether GKE PD CSI uses CSI fsGroup delegation; reclaimPolicy/allowVolumeExpansion of `standard-rwo`; conflicting claim about Standard default StorageClass (in-tree) vs balanced PD.
- Autopilot "warden" constraint text; GKE Standard PSS defaults.
- Cloud NAT / Secure Web Proxy / firewall FQDN / Cloud Armor options for pod egress (not fetched).
- Homebrew install route for gke-gcloud-auth-plugin; kubectl-to-GKE skew statement.
- Google page for checking cluster mode (404 at guessed URL).
- Arm node taint `kubernetes.io/arch=arm64` on Standard/Autopilot.

## Questions a planner must decide
- Cluster mode (Autopilot vs Standard) and Dataplane V2 status determine NetworkPolicy/FQDN availability and default StorageClass.
- Output mode for the exec script (with/without -t) vs. need for separate stderr and clean JSON on stdout.
- Whole-directory vs subPath mount for managed-settings.json.
- Numeric UID/GID and fsGroup values; whether to set readOnlyRootFilesystem and provide writable paths.
- Node architecture (x86 default) vs. build platform on Apple Silicon.
- Whether egress control uses FQDNNetworkPolicy (v1alpha1, needs enablement) or another mechanism.
- PVC retention policy (Retain default vs Delete).

---

# Research: claude-pod wrapper (UUIDv5, Claude Code CLI, kubectl exec)
Date: 2026-11-01. Facts only. [V]=verified on this machine, [D]=from fetched doc/source, [U]=unverified/from general knowledge.

## Q1. UUIDv5

Definition (RFC 9562 sec 5.5, https://www.rfc-editor.org/rfc/rfc9562.html) [D]:
- SHA-1 over (Namespace ID value concatenated with the name), both as canonical octet sequences in network byte order (most significant byte first, sec 4).
- The leftmost 128 bits of the SHA-1 output populate the UUID; the remaining 32 bits are discarded.
- Version replaces the top 4 bits of octet 6 (sec 4.2; v5 = 0101). Variant: top bits of octet 8 = 10 (sec 4.1; octet 8 values 8,9,A,B).
- DNS namespace ID (sec 6.6, Table 3): 6ba7b810-9dad-11d1-80b4-00c04fd430c8.
- RFC 4122 defined the same algorithm for v5 (RFC 9562 obsoletes it). Appendix A test vector: not retrieved (fetch truncated before Appendix A).

CPython reference (https://raw.githubusercontent.com/python/cpython/main/Lib/uuid.py) [D]:
- str name is encoded with bytes(name, "utf-8"); bytes are used as-is.
- h = hashlib.sha1(namespace.bytes + name); first 16 bytes of the digest; clear and set variant/version bits via masks.

Test vector [V], python3 3.14.4:
  uuid.uuid5(uuid.NAMESPACE_DNS, 'python.org') -> 886313e1-3b8a-5372-9b90-0c9aee199e5d
  (this is the commonly cited value from the Python docs/RFC 4122 era)

macOS uuidgen [V]:
- `uuidgen --help` prints only "usage: uuidgen [-hdr]  -hdr emit result in form suitable for copying into a header". man uuidgen (Mac OS X, July 1 2005) documents only -hdr.
- `uuidgen -s -n @dns -N python.org` -> prints the usage text (no output UUID). So macOS uuidgen does NOT support -s/--sha1, -n, -N (those are util-linux uuidgen options; not checked here as no Linux host used).

Other tools on this machine [V]: python3 3.14.4 on PATH and /usr/bin/python3 = 3.9.6 (Xcode CLT; uuid5 exists in both), node v25.6.1 (mise-managed, not system), go 1.27.3 (mise-managed), openssl = LibreSSL 3.3.6, xxd and shasum present, bash 3.2.57 (/bin/bash), zsh shell.
- Node has no built-in uuid5 (crypto has createHash only; the `uuid` npm package would be needed) [U for npm package].

Verified sample, key "alice-session-1", namespace 6ba7b810-9dad-11d1-80b4-00c04fd430c8 (the DNS namespace is used only as an example; the wrapper has its own hard-coded namespace) [V]:
- python3 uuid.uuid5(NS, 'alice-session-1') -> 378908b9-26d0-5f1a-b5ad-78142e25fa5a (version 5, variant "specified in RFC 4122")
- manual hashlib implementation (sha1(ns.bytes + key.encode())[:16], byte6=(b&0x0f)|0x50, byte8=(b&0x3f)|0x80) -> same value.
- pure shell + openssl + xxd:
    h=$( { printf '%s' "$NS" | tr -d - | xxd -r -p; printf '%s' "$k"; } | openssl dgst -sha1 -binary | xxd -p | cut -c1-32 )
    then replace hex char 12 with "5" and hex char 16 with ((c & 3) | 8) -> 378908b9-26d0-5f1a-b5ad-78142e25fa5a (matches python3). Note: my first attempt with a wrong nibble mask produced a malformed 5-char group, so the bit-twiddling needs care (zsh substring syntax ${h:off:len} was used; bash 3.2 supports it too, [U] for bash).
- Non-ASCII key '日本語' -> 9786f370-913c-51ea-845e-7f3469bc5966 (python str encoded as UTF-8).

Encoding gotchas [V]:
- Trailing newline changes the result: 'alice-session-1' -> 378908b9-...; 'alice-session-1\n' -> 933b4773-cd58-5cee-b43c-d7cfa80bc57b. In shell use printf '%s' (not echo) and no here-string (here-strings append a newline).
- Namespace must be hashed as its 16 raw bytes, not as the hex/dashed text.
- Python on macOS: `python3` resolves to a mise/other 3.14.4; /usr/bin/python3 is 3.9.6; both fine. Use `python3 -c 'import sys,uuid; print(uuid.uuid5(uuid.UUID(NS), sys.argv[1]))' "$key"` to avoid quoting/newline issues (argv carries UTF-8 per locale; [U] for locale-dependent decoding with non-UTF-8 locale).

## Q2. Claude Code --session-id

- CLI reference (https://code.claude.com/docs/en/cli-reference) [D]: "`--session-id` | Use a specific session ID for the conversation (must be a valid UUID) | claude --session-id "550e8400-e29b-41d4-a716-446655440000"". The doc does not state a required version; the example 550e8400-e29b-41d4-a716-446655440000 is a version-4 shaped value.
- Whether version nibble 5 is accepted: the docs say only "valid UUID". I did not find a statement either way, and did not run `claude` here to test (no CLI invocation made). Open question for planner: confirm empirically.
- Not found in fetched pages: error text for an invalid --session-id, or behaviour when --session-id is reused for an existing session (the errors page fetch was truncated; see "searched but not found").
- Resume (cli-reference `--resume`/`-r`) [D]: "Resume a specific session by ID or name ... When you pass a session ID, Claude Code searches the current project directory and its git worktrees, then every other project on this machine." Sessions doc (https://code.claude.com/docs/en/sessions): cross-project search resolves the ID only when exactly one other project holds a transcript with messages for it; duplicates cause not-found. If none: `No conversation found with session ID: <session-id>`.
- `--fork-session`: when resuming, create a new session ID instead of reusing the original.
- `-p` sessions are left out of the picker and `--continue` (without -p) but resumable by ID (sessions doc).

## Q3. Remote existence check

Transcript location (sessions doc, "Where transcripts are stored") [D]:
- Default `~/.claude/projects/<project>/<session-id>.jsonl`, <project> = working directory path with non-alphanumerics replaced by `-` (truncated to 200 chars + hash if longer).
- `CLAUDE_CONFIG_DIR` moves storage off ~/.claude. `CLAUDE_CODE_PROJECT_DIR_NAME` (v2.1.234+, 1-64 letters/digits/-/_ ; only honoured when CLAUDE_CONFIG_DIR is set, read from the shell environment of the claude process, not from settings env) pins <project>.
- Docs say transcript entry format is internal; file path pattern is documented.
- Retention: `cleanupPeriodDays`, default 30 days (sessions doc table). `CLAUDE_CODE_SKIP_PROMPT_HISTORY` / `--no-session-persistence` suppress writes (a session started with these has no file).
- Resume by ID is already cross-project, so a `find` over projects/ matches documented lookup semantics except the "exactly one other project holds messages" rule.

kubectl exec [D] (https://kubernetes.io/docs/reference/kubectl/generated/kubectl_exec/):
- Usage: `kubectl exec (POD | TYPE/NAME) [-c CONTAINER] [flags] -- COMMAND [args...]`. Doc comment: use `--` when the command has flags in common with kubectl (e.g. -i); do not quote command+args as one string unless you would normally.
- Flags: -i/--stdin "Pass stdin to the container", -t/--tty "Stdin is a TTY", -q/--quiet.
- Source (kubectl/pkg/cmd/exec/exec.go) [D]: without -i, stdin is disabled (In=nil, TTY=false). If -t is given but stdin is not a terminal, TTY is turned off and a warning "Unable to use a TTY - input is not a terminal or the right kind of file" is printed unless -q.
- Exit status [D partly]: exec.go returns the executor's error unchanged; kubectl/pkg/cmd/util/helpers.go checkErr has `case utilexec.ExitError: handleErr(err.Error(), err.ExitStatus())` and fatal() ends with os.Exit(code). So a remote non-zero exit becomes kubectl's exit code. The message text ("command terminated with exit code N" on stderr) comes from the client-go remotecommand layer, not retrieved [U]. Non-exit failures (pod not found, connection error) exit 1 [U].
- Remote command not found / container runtime exec failure: exit codes like 126/127 or an error from the API; not verified.

Quoting / expansion [U unless noted; standard POSIX shell semantics]:
- `kubectl exec POD -- sh -c '...'`: the single-quoted script is passed intact as one argv element by the local shell; `$CLAUDE_CONFIG_DIR` inside single quotes is expanded by the REMOTE sh. With double quotes locally, the LOCAL shell expands it first (usually empty/wrong).
- The remote sh sees only the container's environment (image ENV, Pod spec env). Variables set only in an interactive login profile are absent in exec.
- `find DIR -name X -print -quit`: -quit is a GNU findutils extension (also supported by busybox? [U] not verified; BSD/macOS find has -quit too in newer versions [U]). If projects dir does not exist, find prints an error to stderr and exits non-zero; with `test -n "$(find ...)"`, the command-substitution exit status is ignored by test, result is exit 1 (empty string) either way, so "missing dir" and "not found" are indistinguishable by exit code unless stderr is inspected.
- `test -n "$(...)"` exit codes: 0 true, 1 false. kubectl propagates them (see above), so 1 is ambiguous with other kubectl failures that exit 1.
- Passing the uuid into sh -c safely: `sh -c 'find ... -name "$1.jsonl" ...' sh "$uuid"` (positional args) avoids interpolating into the script. Because the UUID is generated by hex, injection is not a concern in this specific case [U].
- Shell availability: `sh` exists in practically all images except distroless/scratch; Debian-slim has dash as /bin/sh and bash; Alpine has busybox ash and no bash by default; node:*-slim images include bash [U]. The Claude Code container image must contain `find`; busybox find supports -name -print but `-quit` support not verified. Alternatives that avoid find: shell glob `ls "$CLAUDE_CONFIG_DIR"/projects/*/"$uuid".jsonl` (fixed depth one project level, per documented layout) [U].

## Q4. Parsing `claude -p --output-format json`

Docs (https://code.claude.com/docs/en/headless) [D]:
- `--output-format`: text (default), json "structured JSON with result, session ID, and metadata", stream-json (newline-delimited).
- Example: `session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')` and `claude -p "..." --resume "$session_id"`; `| jq -r '.result'`.
- Exit code: 0 on success, non-zero when the run fails. Invalid flag -> error on stderr before the run. "When a failure happens inside the run, such as missing authentication, Claude Code prints the failure as the result on stdout."
- With json/stream-json output, the "Waiting for background work to finish" line is printed to stderr only, never to JSON on stdout. (Docs: "the line prints only when stdout isn't a terminal, so the JSON your script reads never carries it.")
- Piped stdin cap 10MB. `--bare` recommended for scripted calls (skips hooks, MCP, CLAUDE.md, memory auto-discovery; does not read OAuth/keychain, needs ANTHROPIC_API_KEY or apiKeyHelper or cloud-provider creds).
- Without --bare, `-p` loads hooks from settings and MCP servers (headless doc). Whether hooks/other components can write to stdout in json mode: not documented in what I retrieved.
- Single-object vs array: docs say "structured JSON"; the Agent SDK SDKResultMessage type is documented (https://code.claude.com/docs/en/agent-sdk/typescript):
  success arm: type "result", subtype "success", uuid, session_id, duration_ms, duration_api_ms, is_error, api_error_status?, num_turns, result: string, stop_reason, total_cost_usd, usage, modelUsage, permission_denials, structured_output?, terminal_reason?, ...
  error arm: subtype in error_max_turns | error_during_execution | error_max_budget_usd | error_max_structured_output_retries; has is_error, session_id, errors: string[] and NO `result` field.
  Whether the CLI `--output-format json` stdout is exactly one SDKResultMessage object (vs array in older versions) is not stated in the retrieved pages [U]; --verbose json-array behaviour not checked.
- Consequence for jq: `.result` may be null on error subtypes; check `.is_error`/`.subtype`/`.errors`.
- `--json-schema` adds `structured_output` field.

jq on macOS [V]: /usr/bin/jq exists, `jq --version` = jq-1.7.1-apple (shipped with macOS in this OS version; file dated Sep 24, owner root:wheel). Older macOS releases did not ship jq [U]. python3 json module as alternative: `python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("result"))'` (json parse not executed here, standard library).

Prompt through `kubectl exec` hazards [U, standard shell semantics]:
- `sh -c "claude -p '$prompt'"` re-parses the prompt in the remote shell: quotes, $, backticks, newlines break or inject.
- Options that exist: (a) argv without a shell: `kubectl exec POD -- claude -p --session-id U --output-format json -- "$prompt"` (kubectl passes argv elements as separate strings; no remote shell parsing; leading-dash prompts need `--` or care; whether claude supports `--` end-of-options not verified); (b) stdin: `printf '%s' "$prompt" | kubectl exec -i POD -- claude -p ...`; (c) env var: set via `kubectl exec POD -- env PROMPT=... sh -c 'claude -p "$PROMPT"'` (env visible in remote process list; size limits apply to argv/env: Linux ARG_MAX / per-string 128 KiB MAX_ARG_STRLEN [U]).

## Q5. stdin with `claude -p`

- Documented [D] (headless doc): "Non-interactive mode reads stdin, so you can pipe data in", e.g. `cat build-error.txt | claude -p 'concisely explain ...'`; cli-reference table: `cat logs.txt | claude -p "explain"`. Piped stdin capped at 10MB (non-zero exit with error beyond). If stdin cannot be read, a warning goes to stderr and the command-line prompt is used.
- Errors page index (partial) lists: "Input must be provided either through stdin or as a prompt argument when using --print" and "Error: Input contained only whitespace". So the prompt can come entirely from stdin (no positional prompt); explanations not retrieved.
- When both stdin and a positional prompt are given, doc examples show stdin as data and argv as the instruction (cat file | claude -p 'query'); exact combination semantics for session resume not further documented.
- `--input-format`: text (default) or stream-json (cli-reference).
- Background-work wait note (headless doc): "After Claude finishes its turn and stdin has closed, a claude -p run can stay open to wait for background work" -> stdin closure matters; with `kubectl exec -i` without a pipe/redirect, stdin stays attached to the local terminal and may remain open [U].
- kubectl exec -i [D]: passes local stdin to the container; without -i stdin is nil in the remote process (reads EOF / /dev/null-like behaviour [U]). EOF on local stdin closes remote stdin [U]. Do not use -t with piped input (TTY warning, and a TTY merges stderr into stdout, per exec.go: `p.ErrOut = nil` when TTY raw), which would put stderr text in the JSON stream.
- Resume caveat (sessions doc): `claude -p --resume <session> "prompt"` typed at a terminal on a still-running BACKGROUND session sends the prompt to it and attaches, unless piped/redirected I/O or --output-format json etc. are present, in which case it exits 1 with a message. Not expected for plain Pod sessions but documented.

## Searched but not found
- RFC 9562 Appendix A UUIDv5 test vector text (fetch truncated at 100000 chars; not read further).
- Claude Code docs: any statement of accepted UUID versions for --session-id, error text for invalid --session-id, behaviour when --session-id collides with an existing session (errors page "Command-line errors" section was beyond the first 200000 of ~590000 chars read).
- Exact stdout structure of `--output-format json` in the CLI (single object vs array) and whether it equals SDKResultMessage; not in retrieved pages.
- Source for the client-go "command terminated with exit code" string and exit-code propagation end to end (only the kubectl side was verified).
- No empirical run of `claude`, `kubectl` (kubectl is not installed on this machine: "command not found") or any Pod.
- uuidgen -s on Linux (util-linux) not checked here.
