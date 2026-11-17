use super::{Command, Commands, Failure};
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

fn run(arguments: &[&str], pwe: Option<&Path>) -> Result<String, Failure> {
    let arguments: Vec<String> = arguments.iter().map(|word| word.to_string()).collect();
    Commands { rex: &FakeConfig }.run(&arguments, pwe)
}

fn installed() -> Option<&'static Path> {
    Some(Path::new("/bin/pwe"))
}

#[test]
fn rex_get_loader_prints_the_loader_for_this_pwe() {
    assert_eq!(
        run(&["rex", "get", "loader"], installed()),
        Ok("loader for /bin/pwe".to_string())
    );
}

#[test]
fn rex_get_loader_fails_at_run_time_when_pwe_cannot_tell_where_it_is() {
    let failure = run(&["rex", "get", "loader"], None).unwrap_err();
    assert_eq!(failure.exit_code(), 1);
    assert!(
        failure.message().contains("where it is installed"),
        "{failure:?}"
    );
}

#[cfg(unix)]
#[test]
fn rex_get_loader_fails_at_run_time_when_its_path_is_not_text() {
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;

    let path = Path::new(OsStr::from_bytes(b"/bin/\xffpwe"));
    let failure = run(&["rex", "get", "loader"], Some(path)).unwrap_err();
    assert_eq!(failure.exit_code(), 1);
}

#[test]
fn rex_get_config_prints_the_config() {
    assert_eq!(
        run(&["rex", "get", "config"], None),
        Ok("the config".to_string())
    );
}

#[test]
fn help_is_printed_on_request_at_every_depth() {
    for arguments in [
        &[][..],
        &["help"],
        &["help", "rex"],
        &["-h"],
        &["--help"],
        &["rex", "--help"],
        &["rex", "get", "-h"],
        &["rex", "get", "loader", "--help"],
    ] {
        let help =
            run(arguments, None).unwrap_or_else(|failure| panic!("{arguments:?}: {failure:?}"));
        assert!(help.contains("pwe rex get loader"), "{arguments:?}: {help}");
        assert!(help.contains("pwe rex get config"), "{arguments:?}: {help}");
        assert!(help.contains("Examples:"), "{arguments:?}: {help}");
    }
}

#[test]
fn a_command_pwe_does_not_have_is_a_usage_failure_that_names_it_and_the_way_out() {
    for arguments in [
        &["rex"][..],
        &["rex", "get"],
        &["rex", "get", "keys"],
        &["rex", "get", "loader", "extra"],
        &["navigate"],
    ] {
        let failure = run(arguments, installed()).unwrap_err();
        assert_eq!(failure.exit_code(), 2, "{arguments:?}");
        assert!(
            failure.message().contains(&arguments.join(" ")),
            "{arguments:?}: {failure:?}"
        );
        assert!(
            failure.message().contains("Run: pwe help"),
            "{arguments:?}: {failure:?}"
        );
    }
}
