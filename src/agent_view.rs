#[cfg(test)]
mod tests;

use crate::command::Answer;
use agent::{Agent, Listing, State};
use std::path::Path;
use std::time::SystemTime;

const COLUMNS: usize = 5;

pub fn agent_view(listing: &Listing, home: Option<&Path>) -> Answer {
    let rows: Vec<[String; COLUMNS]> = listing
        .agents
        .iter()
        .map(|agent| row(agent, listing.now, home))
        .collect();
    let error: String = listing
        .failures
        .iter()
        .map(|failure| format!("pwe: {}: {}\n", failure.name, printable(&failure.error)))
        .collect();
    Answer {
        output: table(&rows),
        exit_code: if error.is_empty() { 0 } else { 1 },
        error,
    }
}

fn row(agent: &Agent, now: SystemTime, home: Option<&Path>) -> [String; COLUMNS] {
    [
        state_word(&agent.state).to_string(),
        age(now, agent.since),
        agent.program.to_string(),
        printable(&shown_folder(&agent.folder, home)),
        agent.title.as_deref().map(printable).unwrap_or_default(),
    ]
}

fn table(rows: &[[String; COLUMNS]]) -> String {
    let widths: Vec<usize> = (0..COLUMNS)
        .map(|column| {
            rows.iter()
                .map(|row| row[column].chars().count())
                .max()
                .unwrap_or(0)
        })
        .collect();
    rows.iter()
        .map(|row| {
            let line: Vec<String> = row
                .iter()
                .zip(&widths)
                .map(|(cell, width)| format!("{cell:<width$}"))
                .collect();
            format!("{}\n", line.join("  ").trim_end())
        })
        .collect()
}

fn state_word(state: &State) -> &'static str {
    match state {
        State::Idle => "idle",
        State::Finished => "finished",
        State::Stopped => "stopped",
        State::Working => "working",
        State::NeedsYou { .. } => "needs you",
        State::Busy => "busy",
        State::Retrying => "retrying",
        State::Failed => "failed",
        State::Ended => "ended",
    }
}

fn age(now: SystemTime, since: SystemTime) -> String {
    let seconds = now.duration_since(since).map_or(0, |age| age.as_secs());
    match seconds {
        0..60 => format!("{seconds}s"),
        60..3_600 => format!("{}m", seconds / 60),
        3_600..86_400 => format!("{}h", seconds / 3_600),
        _ => format!("{}d", seconds / 86_400),
    }
}

fn shown_folder(folder: &Path, home: Option<&Path>) -> String {
    match home.and_then(|home| folder.strip_prefix(home).ok()) {
        Some(inside) if inside.as_os_str().is_empty() => "~".to_string(),
        Some(inside) => format!("~/{}", inside.display()),
        None => folder.display().to_string(),
    }
}

fn printable(text: &str) -> String {
    text.chars()
        .filter(|character| !character.is_control())
        .collect()
}
