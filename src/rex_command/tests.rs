use super::RexCommand;
use crate::command::{Answer, Command};
use crate::rex_config::RexConfig;
use std::path::Path;

struct FakeConfig;

impl RexConfig for FakeConfig {
    fn loader(&self, pwe: &str) -> String {
        format!("loader for {pwe}")
    }

    fn config(&self) -> String {
        "the config".to_string()
    }
}

fn rex(pwe: Option<&Path>) -> RexCommand<'_> {
    RexCommand {
        config: &FakeConfig,
        pwe,
    }
}

fn installed() -> Option<&'static Path> {
    Some(Path::new("/bin/pwe"))
}

#[test]
fn get_loader_prints_the_loader_for_this_pwe() {
    assert_eq!(
        rex(installed()).run(&["get", "loader"]),
        Some(Answer::success("loader for /bin/pwe".to_string()))
    );
}

#[test]
fn get_loader_fails_at_run_time_when_pwe_cannot_tell_where_it_is() {
    let answer = rex(None).run(&["get", "loader"]).unwrap();
    assert_eq!(answer.exit_code, 1);
    assert_eq!(answer.output, "");
    assert!(answer.error.contains("where it is installed"), "{answer:?}");
}

#[cfg(unix)]
#[test]
fn get_loader_fails_at_run_time_when_its_path_is_not_text() {
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;

    let path = Path::new(OsStr::from_bytes(b"/bin/\xffpwe"));
    let answer = rex(Some(path)).run(&["get", "loader"]).unwrap();
    assert_eq!(answer.exit_code, 1);
}

#[test]
fn get_config_prints_the_config() {
    assert_eq!(
        rex(None).run(&["get", "config"]),
        Some(Answer::success("the config".to_string()))
    );
}

#[test]
fn words_rex_does_not_have_are_left_to_the_caller() {
    for words in [
        &[][..],
        &["get"],
        &["get", "keys"],
        &["get", "loader", "extra"],
    ] {
        assert_eq!(rex(installed()).run(words), None, "{words:?}");
    }
}

#[test]
fn answers_to_the_word_rex() {
    assert_eq!(rex(None).noun(), "rex");
}
