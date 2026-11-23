check:
    scripts/verify-no-comments.sh
    shasum -a 256 -c --status docs/architecture.sha256 || { echo "docs/architecture.d2 changed: run just diagram"; false; }
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test --lib --bins
    for test in lua-tests/*.lua; do luajit "$test" || exit 1; done

diagram:
    scripts/generate-architecture-diagram.sh
