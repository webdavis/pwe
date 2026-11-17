check:
    ! git grep --untracked -nE '^[[:space:]]*(//|/\*)' -- '*.rs'
    ! git grep --untracked -nE '^[[:space:]]*#' -- justfile '*.toml'
    ! git grep --untracked -nE '^[[:space:]]*--' -- '*.lua'
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test --bins
    luajit lua-tests/rex_navigate.lua
    luajit lua-tests/rex_loader.lua
    luajit lua-tests/nvim_navigate.lua
