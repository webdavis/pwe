use super::time::time_of;
use crate::document::Document;
use crate::json_parser::JsonParser;
use agent::State;
use std::path::PathBuf;
use std::time::SystemTime;

pub struct Session {
    pub folder: PathBuf,
    pub title: Option<String>,
    pub state: State,
    pub since: SystemTime,
}

enum Last {
    Nothing,
    Assistant(SystemTime),
}

pub fn read(content: &str, parser: &dyn JsonParser) -> Option<Session> {
    let mut folder = None;
    let mut began = None;
    let mut title = None;
    let mut last = Last::Nothing;
    for entry in content.lines().filter_map(|line| parser.parse(line)) {
        let at = time(entry.get("timestamp"));
        match entry.get("type").text().unwrap_or_default() {
            "session" => {
                folder = entry.get("cwd").text().map(PathBuf::from);
                began = at;
            }
            "title" | "title_change" => {
                title = entry.get("title").text().map(str::to_string);
            }
            "message" => {
                let message = entry.get("message");
                match message.get("role").text() {
                    Some("assistant") => {
                        if let Some(at) = at {
                            last = Last::Assistant(at);
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        }
    }
    let (state, since) = match last {
        Last::Nothing => (State::Idle, began?),
        Last::Assistant(at) => (State::Finished, at),
    };
    Some(Session {
        folder: folder?,
        title,
        state,
        since,
    })
}

fn time(field: &dyn Document) -> Option<SystemTime> {
    field.text().and_then(time_of)
}
