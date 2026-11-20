use super::time::time_of;
use crate::document::Document;
use crate::json_parser::JsonParser;
use agent::State;
use std::path::PathBuf;
use std::time::SystemTime;

pub struct Session {
    pub folder: PathBuf,
    pub title: Option<String>,
    pub progress: Progress,
}

pub enum Progress {
    Settled(State, SystemTime),
    Waiting(Vec<Call>),
}

pub struct Call {
    pub tool: String,
    pub intent: Option<String>,
    pub started: SystemTime,
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
    let mut pending: Vec<(String, Call)> = Vec::new();
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
            "custom" if is(entry.get("customType"), "tool_execution_start") => {
                let data = entry.get("data");
                if let (Some(id), Some(tool), Some(started)) = (
                    data.get("toolCallId").text(),
                    data.get("toolName").text(),
                    time(data.get("startedAt")).or(at),
                ) {
                    pending.push((
                        id.to_string(),
                        Call {
                            tool: tool.to_string(),
                            intent: data.get("intent").text().map(str::to_string),
                            started,
                        },
                    ));
                }
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
                        pending.clear();
                        last = at.map_or(last, Last::InFlight);
                    }
                    Some("toolResult") => {
                        pending.retain(|(id, _)| !is(message.get("toolCallId"), id));
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
                        if stop != "toolUse" {
                            pending.clear();
                        }
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
    let progress = if pending.is_empty() {
        let (state, since) = match last {
            Last::Nothing => (State::Idle, began?),
            Last::InFlight(at) => (State::Working, at),
            Last::Assistant { stop, at } => (after_reply(&stop, &background), at),
        };
        Progress::Settled(state, since)
    } else {
        Progress::Waiting(pending.into_iter().map(|(_, call)| call).collect())
    };
    Some(Session {
        folder: folder?,
        title,
        progress,
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
