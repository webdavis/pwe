use super::AgentCommand;
use crate::command::Command;
use agent::{Agent, Listing, State};
use std::path::PathBuf;
use std::time::SystemTime;

fn one_agent() -> Listing {
    Listing {
        agents: vec![Agent::new(
            PathBuf::from("/work"),
            State::Working,
            SystemTime::UNIX_EPOCH,
        )],
        failures: vec![],
        now: SystemTime::UNIX_EPOCH,
    }
}

#[test]
fn list_shows_the_listing_it_is_handed() {
    let list = one_agent;
    let agents = AgentCommand {
        list: &list,
        home: None,
    };
    let answer = agents.run(&["list"]).unwrap();
    assert!(answer.output.contains("/work"), "{answer:?}");
}

#[test]
fn words_agent_does_not_have_are_left_to_the_caller() {
    let list = one_agent;
    let agents = AgentCommand {
        list: &list,
        home: None,
    };
    for words in [&[][..], &["list", "extra"], &["show"]] {
        assert_eq!(agents.run(words), None, "{words:?}");
    }
}

#[test]
fn answers_to_the_word_agent() {
    let list = one_agent;
    let agents = AgentCommand {
        list: &list,
        home: None,
    };
    assert_eq!(agents.noun(), "agent");
}
