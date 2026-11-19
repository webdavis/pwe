#[cfg(test)]
mod tests;

use crate::{Agent, State};
use std::cmp::Reverse;
use std::time::{Duration, SystemTime};

const IDLE_AFTER: Duration = Duration::from_secs(10 * 60);

pub trait Harness {
    fn name(&self) -> &'static str;
    fn agents(&self) -> Result<Vec<Agent>, String>;
}

pub trait StatusSource {
    fn name(&self) -> &'static str;
    fn statuses(&self) -> Result<Vec<Status>, String>;
}

#[derive(Clone, Debug, PartialEq)]
#[non_exhaustive]
pub struct Status {
    pub process: Option<u32>,
    pub session: Option<String>,
    pub state: State,
    pub since: SystemTime,
}

impl Status {
    pub fn new(state: State, since: SystemTime) -> Self {
        Self {
            process: None,
            session: None,
            state,
            since,
        }
    }
}

#[derive(Debug, PartialEq)]
pub struct Failure {
    pub name: &'static str,
    pub error: String,
}

#[derive(Debug, PartialEq)]
pub struct Listing {
    pub agents: Vec<Agent>,
    pub failures: Vec<Failure>,
}

pub fn list(harnesses: &[&dyn Harness], sources: &[&dyn StatusSource], now: SystemTime) -> Listing {
    let mut agents = Vec::new();
    let mut failures = Vec::new();
    for harness in harnesses {
        match harness.agents() {
            Ok(found) => agents.extend(found.into_iter().map(|mut agent| {
                agent.program = harness.name();
                agent
            })),
            Err(error) => failures.push(Failure {
                name: harness.name(),
                error,
            }),
        }
    }
    for source in sources {
        match source.statuses() {
            Ok(statuses) => {
                for status in statuses {
                    if let Some(agent) = agents.iter_mut().find(|agent| is_about(agent, &status)) {
                        join(agent, status);
                    }
                }
            }
            Err(error) => failures.push(Failure {
                name: source.name(),
                error,
            }),
        }
    }
    for agent in &mut agents {
        if has_gone_idle(agent, now) {
            agent.state = State::Idle;
        }
    }
    agents.sort_by_key(|agent| (need(&agent.state), Reverse(agent.since)));
    Listing { agents, failures }
}

fn is_about(agent: &Agent, status: &Status) -> bool {
    match (agent.process, status.process) {
        (Some(agent_process), Some(status_process)) => agent_process == status_process,
        _ => agent.session.is_some() && agent.session == status.session,
    }
}

fn join(agent: &mut Agent, status: Status) {
    if agent.state == State::Ended || is_vaguer(&status.state, &agent.state) {
        return;
    }
    agent.state = match (&agent.state, status.state) {
        (State::Failed, State::Working) => State::Retrying,
        (
            State::NeedsYou { kind, text },
            State::NeedsYou {
                kind: status_kind,
                text: status_text,
            },
        ) => State::NeedsYou {
            kind: status_kind.or_else(|| kind.clone()),
            text: status_text.or_else(|| text.clone()),
        },
        (_, state) => state,
    };
    agent.since = status.since;
}

fn is_vaguer(general: &State, specific: &State) -> bool {
    matches!(
        (general, specific),
        (State::Idle, State::Finished | State::Stopped) | (State::Working, State::Retrying)
    )
}

fn has_gone_idle(agent: &Agent, now: SystemTime) -> bool {
    matches!(agent.state, State::Finished | State::Stopped)
        && now
            .duration_since(agent.since)
            .is_ok_and(|age| age >= IDLE_AFTER)
}

fn need(state: &State) -> u8 {
    match state {
        State::NeedsYou { .. } => 0,
        State::Failed => 1,
        State::Finished => 2,
        State::Stopped => 3,
        State::Retrying => 4,
        State::Working => 5,
        State::Busy => 6,
        State::Idle => 7,
        State::Ended => 8,
    }
}
