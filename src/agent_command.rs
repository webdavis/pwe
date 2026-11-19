#[cfg(test)]
mod tests;

use crate::agent_view::agent_view;
use crate::command::{Answer, Command};
use agent::Listing;
use std::path::Path;

const USAGE: &str = "  pwe agent list       List the coding agents running on this machine\n";

const EXAMPLES: &str = "  pwe agent list\n";

pub struct AgentCommand<'a> {
    pub list: &'a dyn Fn() -> Listing,
    pub home: Option<&'a Path>,
}

impl Command for AgentCommand<'_> {
    fn noun(&self) -> &'static str {
        "agent"
    }

    fn usage(&self) -> &'static str {
        USAGE
    }

    fn examples(&self) -> &'static str {
        EXAMPLES
    }

    fn run(&self, words: &[&str]) -> Option<Answer> {
        match words {
            ["list"] => Some(agent_view(&(self.list)(), self.home)),
            _ => None,
        }
    }
}
