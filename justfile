check:
    ! git grep --untracked -nE '^[[:space:]]*(//|/\*)' -- '*.rs'
    ! git grep --untracked -nE '^[[:space:]]*#' -- justfile '*.toml'
    ! git grep --untracked -nE '^[[:space:]]*--' -- '*.lua'
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test --bins
    for test in lua-tests/*.lua; do luajit "$test" || exit 1; done
