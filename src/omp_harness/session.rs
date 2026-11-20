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

pub fn read(content: &str, parser: &dyn JsonParser) -> Option<Session> {
    let mut folder = None;
    let mut began = None;
    let mut title = None;
    for entry in content.lines().map(|line| parser.parse(line).unwrap()) {
        let at = time(entry.get("timestamp"));
        match entry.get("type").text().unwrap_or_default() {
            "session" => {
                folder = entry.get("cwd").text().map(PathBuf::from);
                began = at;
            }
            "title" | "title_change" => {
                title = entry.get("title").text().map(str::to_string);
            }
            _ => {}
        }
    }
    Some(Session {
        folder: folder?,
        title,
        state: State::Idle,
        since: began?,
    })
}

fn time(field: &dyn Document) -> Option<SystemTime> {
    field.text().and_then(time_of)
}
