mod command;
mod rex_config;

use command::{Command, Commands};
use rex_config::EmbeddedRexConfig;
use std::process::ExitCode;

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    let pwe = std::env::current_exe().ok();
    let commands = Commands {
        rex: &EmbeddedRexConfig,
    };
    match commands.run(&arguments, pwe.as_deref()) {
        Ok(output) => {
            print!("{output}");
            ExitCode::SUCCESS
        }
        Err(failure) => {
            eprint!("{}", failure.message());
            ExitCode::from(failure.exit_code())
        }
    }
}
