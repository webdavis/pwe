use super::{Failure, Harness, IDLE_AFTER, Status, StatusSource, list};
use crate::{Agent, State};
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

struct FakeHarness {
    name: &'static str,
    agents: Result<Vec<Agent>, String>,
}

impl Harness for FakeHarness {
    fn name(&self) -> &'static str {
        self.name
    }

    fn agents(&self) -> Result<Vec<Agent>, String> {
        self.agents.clone()
    }
}

struct FakeStatusSource {
    name: &'static str,
    statuses: Result<Vec<Status>, String>,
}

impl StatusSource for FakeStatusSource {
    fn name(&self) -> &'static str {
        self.name
    }

    fn statuses(&self) -> Result<Vec<Status>, String> {
        self.statuses.clone()
    }
}

fn now() -> SystemTime {
    SystemTime::UNIX_EPOCH + Duration::from_secs(1_000_000)
}

fn ago(seconds: u64) -> SystemTime {
    now() - Duration::from_secs(seconds)
}

fn agent(folder: &str, state: State, since: SystemTime) -> Agent {
    Agent::new(PathBuf::from(folder), state, since)
}

fn agent_with_process(process: u32, state: State) -> Agent {
    let mut agent = agent("/work", state, ago(5));
    agent.process = Some(process);
    agent
}

fn status_of_process(process: u32, state: State) -> Status {
    let mut status = Status::new(state, ago(1));
    status.process = Some(process);
    status
}

fn harness(agents: Vec<Agent>) -> FakeHarness {
    FakeHarness {
        name: "omp",
        agents: Ok(agents),
    }
}

fn source(statuses: Vec<Status>) -> FakeStatusSource {
    FakeStatusSource {
        name: "rex",
        statuses: Ok(statuses),
    }
}

fn needs_you(kind: Option<&str>, text: Option<&str>) -> State {
    State::NeedsYou {
        kind: kind.map(str::to_string),
        text: text.map(str::to_string),
    }
}

fn state_after_joining(harness_state: State, source_state: State) -> State {
    let listing = list(
        &[&harness(vec![agent_with_process(7, harness_state)])],
        &[&source(vec![status_of_process(7, source_state)])],
        now(),
    );
    listing.agents[0].state.clone()
}

#[test]
fn every_agent_is_listed_under_the_harness_that_found_it() {
    let omp = harness(vec![agent("/a", State::Working, ago(1))]);
    let claude = FakeHarness {
        name: "claude",
        agents: Ok(vec![agent("/b", State::Working, ago(2))]),
    };
    let listing = list(&[&omp, &claude], &[], now());
    let found: Vec<_> = listing
        .agents
        .iter()
        .map(|agent| (agent.program, agent.folder.clone()))
        .collect();
    assert_eq!(
        found,
        [
            ("omp", PathBuf::from("/a")),
            ("claude", PathBuf::from("/b"))
        ]
    );
    assert!(listing.failures.is_empty());
}

#[test]
fn a_harness_that_fails_is_named_and_the_others_are_still_listed() {
    let broken = FakeHarness {
        name: "codex",
        agents: Err("cannot read its sessions".to_string()),
    };
    let listing = list(
        &[&broken, &harness(vec![agent("/a", State::Working, ago(1))])],
        &[],
        now(),
    );
    assert_eq!(listing.agents.len(), 1);
    assert_eq!(
        listing.failures,
        [Failure {
            name: "codex",
            error: "cannot read its sessions".to_string()
        }]
    );
}

#[test]
fn a_source_that_fails_is_named_and_the_harness_states_stand() {
    let broken = FakeStatusSource {
        name: "rex",
        statuses: Err("rex is not running".to_string()),
    };
    let listing = list(
        &[&harness(vec![agent_with_process(7, State::Busy)])],
        &[&broken],
        now(),
    );
    assert_eq!(listing.agents[0].state, State::Busy);
    assert_eq!(
        listing.failures,
        [Failure {
            name: "rex",
            error: "rex is not running".to_string()
        }]
    );
}

#[test]
fn a_source_makes_a_vague_harness_state_specific() {
    assert_eq!(
        state_after_joining(State::Busy, needs_you(Some("permission"), None)),
        needs_you(Some("permission"), None)
    );
    assert_eq!(
        state_after_joining(State::Busy, State::Working),
        State::Working
    );
}

#[test]
fn a_harness_makes_a_vague_source_state_specific() {
    assert_eq!(
        state_after_joining(State::Stopped, State::Idle),
        State::Stopped
    );
    assert_eq!(
        state_after_joining(State::Finished, State::Idle),
        State::Finished
    );
    assert_eq!(
        state_after_joining(State::Retrying, State::Working),
        State::Retrying
    );
}

#[test]
fn needs_you_keeps_the_kind_and_text_each_side_knows() {
    assert_eq!(
        state_after_joining(
            needs_you(None, Some("Pick a name")),
            needs_you(Some("question"), None)
        ),
        needs_you(Some("question"), Some("Pick a name"))
    );
    assert_eq!(
        state_after_joining(
            needs_you(Some("question"), None),
            needs_you(None, Some("Pick a name"))
        ),
        needs_you(Some("question"), Some("Pick a name"))
    );
}

#[test]
fn needs_you_takes_the_source_kind_and_text_when_both_sides_know_them() {
    assert_eq!(
        state_after_joining(
            needs_you(Some("question"), Some("from the files")),
            needs_you(Some("permission"), Some("from rex"))
        ),
        needs_you(Some("permission"), Some("from rex"))
    );
}

#[test]
fn on_a_true_conflict_the_source_wins() {
    assert_eq!(
        state_after_joining(State::Finished, State::Working),
        State::Working
    );
}

#[test]
fn an_ended_agent_stays_ended_whatever_a_source_still_says() {
    assert_eq!(
        state_after_joining(State::Ended, State::Working),
        State::Ended
    );
}

#[test]
fn a_failed_turn_that_a_source_sees_working_is_retrying() {
    assert_eq!(
        state_after_joining(State::Failed, State::Working),
        State::Retrying
    );
}

#[test]
fn a_status_is_matched_by_session_when_the_process_is_unknown() {
    let mut omp = agent("/a", State::Busy, ago(5));
    omp.session = Some("s1".to_string());
    let mut status = Status::new(State::Working, ago(1));
    status.session = Some("s1".to_string());
    let listing = list(&[&harness(vec![omp])], &[&source(vec![status])], now());
    assert_eq!(listing.agents[0].state, State::Working);
}

#[test]
fn a_status_that_matches_no_agent_changes_nothing() {
    let listing = list(
        &[&harness(vec![agent_with_process(7, State::Busy)])],
        &[&source(vec![status_of_process(8, State::Working)])],
        now(),
    );
    assert_eq!(listing.agents.len(), 1);
    assert_eq!(listing.agents[0].state, State::Busy);
}

#[test]
fn an_agent_and_a_status_that_both_lack_a_process_and_a_session_do_not_match() {
    let status = Status::new(State::Working, ago(1));
    let listing = list(
        &[&harness(vec![agent("/a", State::Busy, ago(5))])],
        &[&source(vec![status])],
        now(),
    );
    assert_eq!(listing.agents[0].state, State::Busy);
}

#[test]
fn the_state_keeps_the_time_of_the_answer_it_came_from() {
    let listing = list(
        &[&harness(vec![agent_with_process(7, State::Busy)])],
        &[&source(vec![status_of_process(7, State::Working)])],
        now(),
    );
    assert_eq!(listing.agents[0].since, ago(1));
}

#[test]
fn only_a_finished_or_stopped_agent_becomes_idle_once_the_idle_time_has_passed() {
    let long_ago = now() - IDLE_AFTER;
    let just_before = long_ago + Duration::from_secs(1);
    let listing = list(
        &[&harness(vec![
            agent("/finished-long-ago", State::Finished, long_ago),
            agent("/stopped-long-ago", State::Stopped, long_ago),
            agent("/failed-long-ago", State::Failed, long_ago),
            agent("/finished-just-now", State::Finished, just_before),
        ])],
        &[],
        now(),
    );
    let state_of = |folder: &str| {
        listing
            .agents
            .iter()
            .find(|agent| agent.folder.as_path() == std::path::Path::new(folder))
            .map(|agent| agent.state.clone())
    };
    assert_eq!(state_of("/finished-long-ago"), Some(State::Idle));
    assert_eq!(state_of("/stopped-long-ago"), Some(State::Idle));
    assert_eq!(state_of("/failed-long-ago"), Some(State::Failed));
    assert_eq!(state_of("/finished-just-now"), Some(State::Finished));
    assert_eq!(listing.now, now());
}

#[test]
fn agents_are_listed_by_need_and_newest_first_within_a_state() {
    let listing = list(
        &[&harness(vec![
            agent("/ended", State::Ended, ago(1)),
            agent("/working-older", State::Working, ago(30)),
            agent("/busy", State::Busy, ago(1)),
            agent("/retrying", State::Retrying, ago(1)),
            agent("/stopped", State::Stopped, ago(1)),
            agent("/working-newer", State::Working, ago(10)),
            agent("/finished", State::Finished, ago(1)),
            agent("/idle", State::Idle, ago(1)),
            agent("/failed", State::Failed, ago(1)),
            agent("/needs-you", needs_you(None, None), ago(1)),
        ])],
        &[],
        now(),
    );
    let folders: Vec<_> = listing
        .agents
        .iter()
        .map(|agent| agent.folder.to_string_lossy().into_owned())
        .collect();
    assert_eq!(
        folders,
        [
            "/needs-you",
            "/failed",
            "/finished",
            "/stopped",
            "/retrying",
            "/working-newer",
            "/working-older",
            "/busy",
            "/idle",
            "/ended",
        ]
    );
}
