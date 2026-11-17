# pwe

## Workflow

- A feature is one thing the owner can do. Before building, state it: "After this, the owner can …; left out: …".
- Build one feature at a time, on one branch, sized to be ready to merge the day it starts. The owner merges.
- At the start, ask in one message for every yes the feature needs: a new outside package, a second package, a test in `tests/`.
- Build the thinnest path that runs end to end first, starting from a failing unit test, then fill the feature in.
- Change only what the task asks. Fix the code, not the test or check that caught it. Changing a wrong test needs the owner's yes.
- Call a feature done only with the output of the command that proves it, run against the built program. When the proof needs Rex, say so, show the output up to the Rex connection, and call it done only after the owner has used it.
- After the merge, give the owner the install command. The next feature starts when he says he used this one.
- `just check` runs `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings` and `cargo test --bins`. Run it before every push. CI runs it too, with `cargo test` in place of `cargo test --bins`.
- On a warm build `just check` takes under 10 seconds and CI under 2 minutes. Report an overrun; never fix one by removing a test or check.
- Delete unused code; never silence the warning.
- After each feature, report the time from go to done, production lines, test lines, tests in `tests/`, and outside packages. Report the time to first use when the owner says he used it.
- When a rule is broken and a command can catch it, add the cheapest such check to `just check`. When no command can, tell the owner instead.
- Write no plan documents.

## Design

- Each feature lives in its own module behind one trait that holds only the methods callers use today. Outside the feature's own module, only `main.rs` names the type behind it.
- Write no comments, doc comments included. Names and structure are the documentation; when code needs explaining, rename or restructure it.

## Tests

- A unit test calls the real feature through its trait and uses hand-written fakes for the traits it depends on. It never sleeps, starts a program, or touches disk or network.
- Write one test per behaviour the feature has, failures included.
- Unit tests live in `src/<feature>/tests.rs`; this replaces the global rule on where tests live. The only test code in `src/<feature>.rs` is `#[cfg(test)] mod tests;`.
- Any other kind of test needs the owner's yes. Name the test and say what a unit test cannot prove.
- The only good reason for one is a real connection that CI can reach, such as the file system; write at most one per connection. CI cannot run Rex, the terminal program this tool talks to, so the Rex connection gets no such test; the owner using the feature proves it.
- Keep connecting code tiny. Decisions live in code a unit test reaches; connecting code only passes messages.
- Other tests live in `tests/main.rs`, run the built program, and run only in CI. Add no `src/lib.rs`.
