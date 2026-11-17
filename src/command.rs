#[cfg(test)]
mod tests;

use crate::rex_config::RexConfig;
use std::path::Path;

const HELP: &str = "\
pwe sets up the keys it shares between Rex and Neovim.

Usage:
  pwe rex get loader   Print the Lua to save beside Rex's init.lua
  pwe rex get config   Print the Lua that loader runs each time Rex loads its config
  pwe help             Print this help

Examples:
  pwe rex get loader > ~/.config/rex/pwe.lua
  pwe rex get config | less
  pwe rex get loader --help
";

#[derive(Debug, PartialEq)]
pub enum Failure {
    Usage(String),
    Runtime(String),
}

impl Failure {
    pub fn message(&self) -> &str {
        match self {
            Failure::Usage(message) | Failure::Runtime(message) => message,
        }
    }

    pub fn exit_code(&self) -> u8 {
        match self {
            Failure::Usage(_) => 2,
            Failure::Runtime(_) => 1,
        }
    }
}

pub trait Command {
    fn run(&self, arguments: &[String], pwe: Option<&Path>) -> Result<String, Failure>;
}

pub struct Commands<'rex> {
    pub rex: &'rex dyn RexConfig,
}

impl Command for Commands<'_> {
    fn run(&self, arguments: &[String], pwe: Option<&Path>) -> Result<String, Failure> {
        let words: Vec<&str> = arguments.iter().map(String::as_str).collect();
        match words.as_slice() {
            [] | ["help", ..] | [.., "-h" | "--help"] => Ok(HELP.to_string()),
            ["rex", "get", "loader"] => pwe
                .and_then(Path::to_str)
                .map(|pwe| self.rex.loader(pwe))
                .ok_or_else(|| {
                    Failure::Runtime("pwe: cannot tell where it is installed\n".to_string())
                }),
            ["rex", "get", "config"] => Ok(self.rex.config().to_string()),
            _ => Err(Failure::Usage(format!(
                "pwe: unknown command \"{}\"\nRun: pwe help\n",
                words.join(" ")
            ))),
        }
    }
}
