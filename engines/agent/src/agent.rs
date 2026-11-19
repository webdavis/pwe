use std::path::PathBuf;
use std::time::SystemTime;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum State {
    Idle,
    Finished,
    Stopped,
    Working,
    NeedsYou {
        kind: Option<String>,
        text: Option<String>,
    },
    Busy,
    Retrying,
    Failed,
    Ended,
}

#[derive(Clone, Debug, PartialEq)]
#[non_exhaustive]
pub struct Agent {
    pub program: &'static str,
    pub folder: PathBuf,
    pub state: State,
    pub since: SystemTime,
    pub session: Option<String>,
    pub title: Option<String>,
    pub process: Option<u32>,
}

impl Agent {
    pub fn new(folder: PathBuf, state: State, since: SystemTime) -> Self {
        Self {
            program: "",
            folder,
            state,
            since,
            session: None,
            title: None,
            process: None,
        }
    }
}
