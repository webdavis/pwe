#[cfg(test)]
mod tests;

const DESCRIPTION: &str = "pwe sets up the keys it shares between Rex and Neovim.\n";
const HELP_USAGE: &str = "  pwe help             Print this help\n";

#[derive(Debug, PartialEq)]
pub struct Answer {
    pub output: String,
    pub error: String,
    pub exit_code: u8,
}

impl Answer {
    pub fn success(output: String) -> Self {
        Self {
            output,
            error: String::new(),
            exit_code: 0,
        }
    }

    pub fn runtime_failure(error: String) -> Self {
        Self {
            output: String::new(),
            error,
            exit_code: 1,
        }
    }

    pub fn usage_failure(error: String) -> Self {
        Self {
            output: String::new(),
            error,
            exit_code: 2,
        }
    }
}

pub trait Command {
    fn noun(&self) -> &'static str;
    fn usage(&self) -> &'static str;
    fn examples(&self) -> &'static str;
    fn run(&self, words: &[&str]) -> Option<Answer>;
}

pub struct Commands<'nouns> {
    pub nouns: &'nouns [&'nouns dyn Command],
}

impl Commands<'_> {
    pub fn run(&self, arguments: &[String]) -> Answer {
        let words: Vec<&str> = arguments.iter().map(String::as_str).collect();
        match words.split_first() {
            None | Some((&"help", _)) => Answer::success(self.help()),
            _ if words.iter().any(|word| matches!(*word, "-h" | "--help")) => {
                Answer::success(self.help())
            }
            Some((noun, rest)) => self
                .nouns
                .iter()
                .find(|command| command.noun() == *noun)
                .and_then(|command| command.run(rest))
                .unwrap_or_else(|| {
                    Answer::usage_failure(format!(
                        "pwe: unknown command \"{}\"\nRun: pwe help\n",
                        words.join(" ")
                    ))
                }),
        }
    }

    fn help(&self) -> String {
        let usage: String = self.nouns.iter().map(|noun| noun.usage()).collect();
        let examples: String = self.nouns.iter().map(|noun| noun.examples()).collect();
        format!("{DESCRIPTION}\nUsage:\n{usage}{HELP_USAGE}\nExamples:\n{examples}")
    }
}
