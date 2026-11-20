use crate::json_parser::JsonParser;
use std::path::PathBuf;

pub struct Session {
    pub folder: PathBuf,
    pub title: Option<String>,
}

pub fn read(content: &str, parser: &dyn JsonParser) -> Option<Session> {
    let mut folder = None;
    let mut title = None;
    for entry in content.lines().map(|line| parser.parse(line).unwrap()) {
        match entry.get("type").text().unwrap_or_default() {
            "session" => {
                folder = entry.get("cwd").text().map(PathBuf::from);
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
    })
}
