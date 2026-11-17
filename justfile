check:
    ! git grep --untracked -nE '^[[:space:]]*(//|/\*)' -- '*.rs'
    ! git grep --untracked -nE '^[[:space:]]*#' -- justfile '*.toml'
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test --bins
