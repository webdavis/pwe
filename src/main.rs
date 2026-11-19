mod agent_command;
mod agent_view;
mod command;
mod rex_command;
mod rex_config;

use agent_command::AgentCommand;
use command::Commands;
use rex_command::RexCommand;
use rex_config::EmbeddedRexConfig;
use std::process::ExitCode;
use std::time::SystemTime;

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    let pwe = std::env::current_exe().ok();
    let home = std::env::home_dir();
    let rex = RexCommand {
        config: &EmbeddedRexConfig,
        pwe: pwe.as_deref(),
    };
    let list = || agent::list(&[], &[], SystemTime::now());
    let agents = AgentCommand {
        list: &list,
        home: home.as_deref(),
    };
    let answer = Commands {
        nouns: &[&rex, &agents],
    }
    .run(&arguments);
    print!("{}", answer.output);
    eprint!("{}", answer.error);
    ExitCode::from(answer.exit_code)
}
