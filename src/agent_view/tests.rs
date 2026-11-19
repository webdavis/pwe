use super::agent_view;
use crate::command::Answer;
use agent::{Agent, Failure, Listing, State};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

fn now() -> SystemTime {
    SystemTime::UNIX_EPOCH + Duration::from_secs(1_000_000)
}

fn ago(seconds: u64) -> SystemTime {
    now() - Duration::from_secs(seconds)
}

fn agent(program: &'static str, folder: &str, state: State, since: SystemTime) -> Agent {
    let mut agent = Agent::new(PathBuf::from(folder), state, since);
    agent.program = program;
    agent
}

fn listing(agents: Vec<Agent>, failures: Vec<Failure>) -> Listing {
    Listing {
        agents,
        failures,
        now: now(),
    }
}

fn row_of(agent: Agent, home: Option<&Path>) -> String {
    agent_view(&listing(vec![agent], vec![]), home).output
}

#[test]
fn each_agent_is_a_row_with_its_columns_lined_up() {
    let mut waiting = agent(
        "omp",
        "/Users/me/pwe",
        State::NeedsYou {
            kind: None,
            text: None,
        },
        ago(180),
    );
    waiting.title = Some("Fix the login bug".to_string());
    let working = agent("claude", "/tmp/x", State::Working, ago(5));
    assert_eq!(
        agent_view(&listing(vec![waiting, working], vec![]), None),
        Answer::success(
            "needs you  3m  omp     /Users/me/pwe  Fix the login bug\n\
             working    5s  claude  /tmp/x\n"
                .to_string()
        )
    );
}

#[test]
fn an_age_is_shown_in_its_largest_whole_unit() {
    for (seconds, shown) in [
        (59, "59s"),
        (60, "1m"),
        (3_599, "59m"),
        (3_600, "1h"),
        (86_399, "23h"),
        (86_400, "1d"),
    ] {
        assert_eq!(
            row_of(agent("omp", "/a", State::Working, ago(seconds)), None),
            format!("working  {shown}  omp  /a\n")
        );
    }
}

#[test]
fn a_folder_inside_home_starts_with_a_tilde() {
    let home = Some(Path::new("/Users/me"));
    for (folder, shown) in [
        ("/Users/me/pwe", "~/pwe"),
        ("/Users/me", "~"),
        ("/Users/meow", "/Users/meow"),
    ] {
        assert_eq!(
            row_of(agent("omp", folder, State::Working, ago(1)), home),
            format!("working  1s  omp  {shown}\n")
        );
    }
}

#[test]
fn control_characters_from_agent_programs_are_not_printed() {
    let mut odd = agent("omp", "/a\u{7}b", State::Working, ago(1));
    odd.title = Some("red \u{1b}[31mtext".to_string());
    let answer = agent_view(
        &listing(
            vec![odd],
            vec![Failure {
                name: "codex",
                error: "bad \u{1b}]0;title\u{7}file".to_string(),
            }],
        ),
        None,
    );
    assert_eq!(answer.output, "working  1s  omp  /ab  red [31mtext\n");
    assert_eq!(answer.error, "pwe: codex: bad ]0;titlefile\n");
}

#[test]
fn no_agents_prints_nothing() {
    assert_eq!(
        agent_view(&listing(vec![], vec![]), None),
        Answer::success(String::new())
    );
}

#[test]
fn each_failure_is_an_error_line_and_the_agents_read_are_still_shown() {
    let answer = agent_view(
        &listing(
            vec![agent("omp", "/a", State::Working, ago(1))],
            vec![
                Failure {
                    name: "codex",
                    error: "cannot read its sessions".to_string(),
                },
                Failure {
                    name: "rex",
                    error: "rex is not running".to_string(),
                },
            ],
        ),
        None,
    );
    assert_eq!(answer.output, "working  1s  omp  /a\n");
    assert_eq!(
        answer.error,
        "pwe: codex: cannot read its sessions\npwe: rex: rex is not running\n"
    );
    assert_eq!(answer.exit_code, 1);
}
