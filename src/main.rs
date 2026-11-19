mod command;
mod rex_command;
mod rex_config;

use command::Commands;
use rex_command::RexCommand;
use rex_config::EmbeddedRexConfig;
use std::process::ExitCode;

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    let pwe = std::env::current_exe().ok();
    let rex = RexCommand {
        config: &EmbeddedRexConfig,
        pwe: pwe.as_deref(),
    };
    let answer = Commands { nouns: &[&rex] }.run(&arguments);
    print!("{}", answer.output);
    eprint!("{}", answer.error);
    ExitCode::from(answer.exit_code)
}
