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
    InFlight(SystemTime),
    Assistant { stop: String, at: SystemTime },
}

pub fn read(content: &str, parser: &dyn JsonParser) -> Option<Session> {
    let mut folder = None;
    let mut began = None;
    let mut title = None;
    let mut background: Vec<String> = Vec::new();
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
            "custom_message" if is(entry.get("customType"), "async-result") => {
                for job in entry.get("details").get("jobs").items() {
                    background.retain(|running| !is(job.get("jobId"), running));
                }
                last = at.map_or(last, Last::InFlight);
            }
            "message" => {
                let message = entry.get("message");
                match message.get("role").text() {
                    Some("user") => {
                        last = at.map_or(last, Last::InFlight);
                    }
                    Some("toolResult") => {
                        let job = message.get("details").get("async");
                        if let (Some("running"), Some(id)) =
                            (job.get("state").text(), job.get("jobId").text())
                        {
                            background.push(id.to_string());
                        }
                        last = at.map_or(last, Last::InFlight);
                    }
                    Some("assistant") => {
                        let stop = message.get("stopReason").text().unwrap_or_default();
                        if let Some(at) = at {
                            last = Last::Assistant {
                                stop: stop.to_string(),
                                at,
                            };
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
        Last::InFlight(at) => (State::Working, at),
        Last::Assistant { stop, at } => (after_reply(&stop, &background), at),
    };
    Some(Session {
        folder: folder?,
        title,
        state,
        since,
    })
}

fn after_reply(stop: &str, background: &[String]) -> State {
    match stop {
        "stop" if background.is_empty() => State::Finished,
        "stop" => State::Working,
        "aborted" => State::Stopped,
        _ => State::Busy,
    }
}

fn time(field: &dyn Document) -> Option<SystemTime> {
    field.text().and_then(time_of)
}

fn is(field: &dyn Document, text: &str) -> bool {
    field.text() == Some(text)
}
