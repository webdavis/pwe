check:
    ! git grep --untracked -nE '^[[:space:]]*(//|/\*)' -- '*.rs'
    ! git grep --untracked -nE '^[[:space:]]*#' -- justfile '*.toml'
    ! git grep --untracked -nE '^[[:space:]]*--' -- '*.lua'
    shasum -a 256 -c --status docs/architecture.sha256 || { echo "docs/architecture.json changed: run just diagram"; false; }
    cargo fmt --check
    cargo clippy --all-targets -- -D warnings
    cargo test --bins
    for test in lua-tests/*.lua; do luajit "$test" || exit 1; done

diagram:
    trash .archify 2>/dev/null || true
    node "${ARCHIFY:-$HOME/.omp/agent/skills/archify/bin/archify.mjs}" finalize architecture docs/architecture.json .archify/architecture.html --quality showcase
    node "${ARCHIFY:-$HOME/.omp/agent/skills/archify/bin/archify.mjs}" visual-check .archify/architecture.html --summary --require-provenance --out-dir .archify/visual-check
    cp .archify/visual-check/architecture.visual-check.2048x1320.dark.png docs/architecture.png
    shasum -a 256 docs/architecture.json > docs/architecture.sha256
