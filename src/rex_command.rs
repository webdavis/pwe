#[cfg(test)]
mod tests;

use crate::command::{Answer, Command};
use crate::rex_config::RexConfig;
use std::path::Path;

const USAGE: &str = "  pwe rex get loader   Print the Lua to save beside Rex's init.lua
  pwe rex get config   Print the Lua that loader runs each time Rex loads its config
";

const EXAMPLES: &str = "  pwe rex get loader > ~/.config/rex/pwe.lua
  echo 'require(\"pwe\").setup()' >> ~/.config/rex/init.lua
  pwe rex get config | less
";

pub struct RexCommand<'a> {
    pub config: &'a dyn RexConfig,
    pub pwe: Option<&'a Path>,
}

impl Command for RexCommand<'_> {
    fn noun(&self) -> &'static str {
        "rex"
    }

    fn usage(&self) -> &'static str {
        USAGE
    }

    fn examples(&self) -> &'static str {
        EXAMPLES
    }

    fn run(&self, words: &[&str]) -> Option<Answer> {
        match words {
            ["get", "loader"] => Some(
                self.pwe
                    .and_then(Path::to_str)
                    .map(|pwe| Answer::success(self.config.loader(pwe)))
                    .unwrap_or_else(|| {
                        Answer::runtime_failure(
                            "pwe: cannot tell where it is installed\n".to_string(),
                        )
                    }),
            ),
            ["get", "config"] => Some(Answer::success(self.config.config())),
            _ => None,
        }
    }
}
