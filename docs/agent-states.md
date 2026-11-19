# Agent states: what each program can report

The evidence behind the states in `docs/architecture.md`. Agent programs update themselves, so every finding carries a version and a date. Retest before relying on a finding from an older version, and add what you test.

Before any test session:

- The owner's hooks and extensions send notices to his phone. Keep them out of every test session, and show on the first one that no `pns` process started.
- Use only sessions you start, on the smallest model.

"Base" is what a program leaves readable with nothing installed. "Rex" is what the program reports to its Rex pane, read with `rex block call -s SESSION -b BLOCK program_status`, tested on Rex 0.1.0-preview.20. "Hooks" is what the program's own hooks or events report. `idle` is `finished` or `stopped` plus elapsed time, for every program.

## omp

Tested on 19.0.0, 2026-11-19. A pending tool is a `tool_execution_start` entry in the session file with no result after it.

| State | Base | Rex | Hooks |
| --- | --- | --- | --- |
| `needs you`: question | yes, with text: pending `ask` | yes, with text | yes |
| `needs you`: approval | no; with omp's relay on, `omp collab list --json` gives `inputRequired`, without kind or text (18.22.2) | yes, every tool kind, with text | yes: `tool_approval_requested` |
| `working` | for `bash`, `eval` and `task` only (see below) | yes | yes |
| `busy` | every other pending tool | never | never |
| `finished` | last assistant message has `stopReason` `stop`, and no background job is open | `done` | `session_stop`, with no failed `auto_retry_end` before it |
| `stopped` | last assistant message has `stopReason` `aborted` | no: says `idle` | `agent_end` after `aborted`, with no `session_stop` |
| `retrying` | several errors in the turn, none marked `retryRecovery` | no: says `working` | `auto_retry_start` |
| `failed` | earlier errors marked `retryRecovery.status` `superseded` | `error` | `auto_retry_end` with `success: false`; `session_stop` also fires |
| `ended` | `omp session lease` not held; `session_exit` says how | record cleared; stale after a hard kill | `session_shutdown`; nothing on a hard kill |

- **Stopped.** `aborted` also follows a rule that stopped the agent, which may then carry on by itself. pwe knows the turn was cut off, not who cut it off.
- **Working, from base.** omp creates `<session folder>/local/N.log` when a `bash` or `eval` call really starts, and `<session folder>/<Name>.jsonl` when a subagent starts. A file created at or after the call's `startedAt` means `working`. The file stays afterwards, so compare times. omp 18.22 created no such file: without it, show `busy`.
- **Background work.** A tool result with `details.async.state` `running` and a job id, with no later `async-result` message for that id.
- **First retry.** Between the first error and the second attempt's result, a retry looks like a final failure in the file. Rex or a hook settles it.
- **Alive.** Ids come from lock file names in `~/.omp/run/session-owners/`. Lock files stay after exit; only the lease is the live test. Sessions named `…__advisor` hold leases and are not agents.
- **Pane.** Rex's record gives the omp process id; `~/.omp/agent/terminal-sessions/<tty>` names that terminal's session file.
- **Not reliable:** the macOS power-saving lock (a setting turns it off, and a background command does not hold it); the time a pending `edit` has waited.
- **Not tested:** a pending `edit` with formatting on; a sign-in wait.

## Claude Code

Tested on 2.1.325, 2026-11-19. R is `~/.claude/sessions/<pid>.json`. T is the transcript `~/.claude/projects/<slug>/<sessionId>.jsonl`.

| State | Base | Rex | Hooks |
| --- | --- | --- | --- |
| `working` | R `status` `busy`, no `waitingFor` | `working` | `UserPromptSubmit`, `PreToolUse` |
| `needs you` | R `status` `waiting`, with `waitingFor` giving the kind; text from T's last unanswered `tool_use` | `blocked`, with kind and text | `PermissionRequest`, `Elicitation` |
| `finished` | R `idle`, and T ends with `stop_reason` `end_turn` | `done` | `Stop` |
| `stopped` | R `idle`, and T's last user text is an interrupt marker | no: says `idle` | settings hooks: no; a plugin's `turn.complete` with `isAborted: true` |
| `retrying` | R `busy`, and repeated `api-request` records in T with no assistant record between | no: says `working` | no |
| `failed` | T assistant record with `isApiErrorMessage` | `error` | `StopFailure` |
| `ended` | R file gone, or its pid dead | record cleared | `SessionEnd`; nothing on a hard kill |
| `busy` | never needed | never | after `PermissionRequest`, until the tool finishes |

- R also has `status` `shell`: the turn is over and a background command still runs. Rex says `done` there.
- **Not tested:** background sessions (`claude --bg`); a sign-in wait.

## Codex

Tested on 0.169.0 and 0.170.0, 2026-11-19. The transcript is `~/.codex/sessions/…/rollout-*-<id>.jsonl`.

| State | Base | Rex | Hooks |
| --- | --- | --- | --- |
| `needs you`: question | yes, with text: pending `request_user_input` | `blocked`, `question`, no text | `PreToolUse` |
| `needs you`: approval | no: nothing is written while the prompt is up | `blocked`, `permission`, no text | `PermissionRequest`, with text |
| `working` | without the server only: a turn is open, and no tool call is pending or a command runs as a child that is not an MCP server or `codex-code-mode-host` | `working` | yes |
| `busy` | without the server only: a tool call pending with no such child | never | never |
| `finished` | `task_complete` without `error` | `done`, until the next key press | `Stop` |
| `stopped` | `turn_aborted` | no: says `idle` | `Interrupt` |
| `retrying` | no | no: says `working` | a failed `PostModelRequest`, then a new attempt |
| `failed` | `task_complete.error` | `error` | inferred: the last model attempt failed and no `Stop` came |
| `ended` | see below | record cleared | `SessionEnd`, on a clean quit only |

- **With the background server on, which is Codex's default,** one server process holds the lock of every session and keeps it after `/quit`. From base, a quit session looks like an open one, and no fact ties a window to its session. Matching by folder attaches a quit session to a new window. Show a Codex window by its folder and its Rex state, and name no session.
- **Without the server** (`--no-daemon`), `ended` is "no process holds `~/.codex/thread-writer-locks/<id>.lock`".
- **Not tested:** hooks with the server on; an interrupt with the server on; the automatic approval reviewer.
