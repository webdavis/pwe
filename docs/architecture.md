# Architecture

![The design](architecture.png)

The picture is drawn from `docs/architecture.json`. `<Name>` is a trait. `name()` is a plain function.

## Packages

| Package | Path | May use |
| --- | --- | --- |
| program | repo root | the core, `serde_json` |
| agent core | `engines/agent` | the standard library |

A second engine gets its own package under `engines/`. The workspace lists `members = ["engines/*"]` and `default-members = [".", "engines/*"]`, so a plain `cargo test` covers every engine; `cargo test -p pwe` does not. The compiler does not report unused public parts of a core, so delete what the program stops using.

## The core

- `Agent` is one running session of one agent program: which program, its folder, its `State` and when that state began, and where known its session, title and process. A harness makes one with `Agent::new` from the folder, state and time, the only way the compiler allows outside the core; every other fact starts unknown, so a new fact touches no harness. `list()` fills in the program from the harness's name.
- `<Harness>` is one agent program, such as omp. It lists its agents and reports each fact it can know.
- `<StatusSource>` is anything else that knows an agent's state, such as Rex.
- An ability only some programs have, such as sending a message, gets its own small trait that only those harnesses implement.
- `list()` asks every harness and every source and returns a `Listing`: the agents, the time it was made, and each harness or source that failed. It changes nothing. Ages and `idle` both use that one time.
- An implementation is named after its trait with words added: `OmpHarness`.

The core takes every fact as a value, the current time included.

`list()` joins what a harness and a source say about the same agent, matched by process where both know it, otherwise by session where both know it. When the two answers fit together, it keeps the more specific one: Rex `idle` and a file's `stopped` give `stopped`. When they truly conflict, the program's live report wins over its files, with two exceptions: a harness's `ended` always stands, because a source's record can outlive the process, and a harness's `failed` with a source's `working` is `retrying`. A program reporting it is blocked for a reason pwe does not know gives `needs you`.

## The program

- **Harness module**: one per agent program (`OmpHarness`, `ClaudeCodeHarness`, `CodexHarness`). It holds that program's paths, commands and rules, and reaches the machine only through the readers. A fact only one program has stays inside its module. It uses what the program reports before working a state out from its files.
- **Readers**: `<Disk>` and `<Programs>`, shared by every harness. `LocalDisk` reads and `LocalPrograms` runs. They hold no rules.
- **Rex source**: runs the `rex` program. Rex's socket waits until a view needs live updates.
- **Presentation**: a plain function per view, from a `Listing` to what is shown. Each row shows how long its agent has been in its state, such as `finished 2m`. Text read from an agent program's files is printed with its control characters removed, so it cannot steer the terminal.
- **Command line**: each noun implements `<Command>` (`RexCommand`, `AgentCommand`) and gives its words and its lines of help. `Commands` hands the words to the noun and is not itself a `<Command>`. An answer carries the output, the error text and the exit code. `AgentCommand` holds a function that returns a `Listing`, so a list fed later by a background process changes only `main.rs`; its tests hand it a made-up one.
- **Failures**: when a harness or source fails, `pwe agent list` shows the agents it read, prints one error line for each failure, and exits 1.
- **`main.rs`**: builds the real types and hands them to each other. It is the only file that names them. It hands over raw values, even a missing one, and the code that receives a value decides what to do without it.

Adding an agent program is one new harness module and its lines in `main.rs`.

## Agent states

| State | Meaning |
| --- | --- |
| `idle` | `finished` or `stopped` for 10 minutes or more. |
| `finished` | Its last turn completed less than 10 minutes ago. |
| `stopped` | Its last turn was cut off before completing. |
| `working` | In a turn, and known not to be waiting. |
| `needs you` | In a turn and stopped until the owner acts, with the kind and the text when known. |
| `busy` | In a turn; pwe cannot tell whether it is working or waiting. |
| `retrying` | A model request failed and the program is trying again. |
| `failed` | A turn ended in an error. |
| `ended` | The session's process is gone. |

1. **Show only what pwe can capture.** A state is offered for a program once a test recorded in `docs/agent-states.md` shows pwe reading it correctly. Combining several facts counts.
2. **Choose the best source for each state separately.** A program's own files, Rex and hooks each see things the others miss.
3. **When pwe cannot tell, say `busy`.**
4. **List by need:** `needs you`, `failed`, `finished`, `stopped`, `retrying`, `working`, `busy`, `idle`, `ended`; newest first within a state.

The 10 minutes lives in one place in the core, and tests do not repeat the number. The owner came back to 92% of finished omp turns within 10 minutes, 87% within 5 and 96% within 30.

## Rejected

| Idea | Why |
| --- | --- |
| A `just check` search that keeps program names out of the core | The core cannot use the program: it does not depend on it, so the build fails. The word "omp" in a core string harms nothing. |
| The core reading a program's files itself | Its tests would touch disk, and each new program would add its own case to the core. |
| A joined harness that is itself a `<Harness>` | `list()` walks a plain list. |
| One reader trait per harness | It puts each program's paths and commands in code no test reaches. |
| A view trait, view model or presenter type | One view exists. Add the trait when one running program feeds two live views. |
| A rule that depends on a setting the owner can change | He may change it. |
| A core without the standard library | The owner kept the full standard library. |
| pwe starting agents (`omp --mode rpc`, `omp acp`) or `omp stream` | pwe only reads. `omp stream` broadcasts the screen publicly. |
| Comparing the real module graph with the design in `just check` | A script policing the design. Packages are the compiler-checked boundary. |
| The name "may need you" for `busy` | Indirect. `busy` is the agent programs' own word. |
| A timing rule for whether a pending omp edit awaits approval | A guess; the edit is `busy`. |

## Not built yet

Each line is one pull request, in this order. Delete a line when it is built.

2. The `engines/agent` package and the core, tested with made-up harnesses and sources. `default-members` makes a plain `cargo test` cover it, and `just check` runs `cargo test --lib --bins`.
3. `pwe agent list`, connected with no harness.
4. `OmpHarness`, from omp's own files.
5. A Rex status source.
6. `ClaudeCodeHarness`.
7. `CodexHarness`, after its hooks are tested with its background server on. It gives each window's process id, since Rex can join a Codex window by nothing else.
8. omp's relay, as a source: `omp collab list` says when an agent needs input, and omp's files cover each agent the relay does not list. It needs a relay program kept running; retest on the current omp first.
9. Hooks, as a third source, offered as an optional pwe install that says which states it adds.
