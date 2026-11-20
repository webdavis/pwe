use super::OmpHarness;
use crate::disk::Disk;
use crate::document::Document;
use crate::json_parser::JsonParser;
use crate::programs::Programs;
use agent::{Harness, State};
use std::cell::RefCell;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

const ID: &str = "01a1-session";
const SESSIONS: &str = "/home/.omp/agent/sessions/-work";
const OWNERS: &str = "/home/.omp/run/session-owners";
const HOLDING_THE_SESSION: &str = "omp holds the session";
const HOLDING_NOTHING: &str = "omp holds nothing";

#[derive(Debug, PartialEq)]
enum DiskCall {
    Entries(PathBuf),
    Read(PathBuf),
}

#[derive(Default)]
struct DiskSpy {
    files: BTreeMap<PathBuf, String>,
    calls: RefCell<Vec<DiskCall>>,
}

impl DiskSpy {
    fn add(&mut self, path: &str, content: &str) {
        self.files.insert(PathBuf::from(path), content.to_string());
    }
}

impl Disk for DiskSpy {
    fn entries(&self, folder: &Path) -> Vec<PathBuf> {
        self.calls
            .borrow_mut()
            .push(DiskCall::Entries(folder.to_path_buf()));
        let mut found: Vec<PathBuf> = self
            .files
            .keys()
            .filter_map(|path| {
                let inside = path.strip_prefix(folder).ok()?;
                inside.components().next().map(|first| folder.join(first))
            })
            .collect();
        found.dedup();
        found
    }

    fn read(&self, file: &Path) -> Option<String> {
        self.calls
            .borrow_mut()
            .push(DiskCall::Read(file.to_path_buf()));
        self.files.get(file).cloned()
    }
}

#[derive(Debug, PartialEq)]
struct Run {
    program: String,
    arguments: Vec<String>,
}

struct ProgramsSpy {
    answer: Result<String, String>,
    runs: RefCell<Vec<Run>>,
}

impl Programs for ProgramsSpy {
    fn run(&self, program: &str, arguments: &[&str]) -> Result<String, String> {
        self.runs.borrow_mut().push(Run {
            program: program.to_string(),
            arguments: arguments
                .iter()
                .map(|argument| argument.to_string())
                .collect(),
        });
        self.answer.clone()
    }
}

#[derive(Clone)]
enum Tree {
    Text(String),
    List(Vec<Tree>),
    Fields(BTreeMap<String, Tree>),
    Missing,
}

static MISSING: Tree = Tree::Missing;

impl Document for Tree {
    fn get(&self, name: &str) -> &dyn Document {
        match self {
            Tree::Fields(fields) => fields.get(name).unwrap_or(&MISSING),
            _ => &MISSING,
        }
    }

    fn text(&self) -> Option<&str> {
        match self {
            Tree::Text(text) => Some(text),
            _ => None,
        }
    }

    fn items(&self) -> Box<dyn Iterator<Item = &dyn Document> + '_> {
        match self {
            Tree::List(items) => Box::new(items.iter().map(|item| item as &dyn Document)),
            _ => Box::new(std::iter::empty()),
        }
    }
}

#[derive(Default)]
struct JsonParserStub {
    documents: BTreeMap<String, Tree>,
}

impl JsonParser for JsonParserStub {
    fn parse(&self, text: &str) -> Option<Box<dyn Document>> {
        match self.documents.get(text)? {
            Tree::Missing => None,
            tree => Some(Box::new(tree.clone())),
        }
    }
}

struct Sut {
    disk: DiskSpy,
    programs: ProgramsSpy,
    parser: JsonParserStub,
    home: Option<&'static Path>,
}

impl Sut {
    fn harness(&self) -> OmpHarness<'_> {
        OmpHarness {
            disk: &self.disk,
            programs: &self.programs,
            parser: &self.parser,
            home: self.home,
        }
    }
}

fn make_sut(lines: &[Tree]) -> Sut {
    let mut parser = JsonParserStub::default();
    parser
        .documents
        .insert(HOLDING_THE_SESSION.to_string(), lease(&[ID]));
    parser
        .documents
        .insert(HOLDING_NOTHING.to_string(), lease(&[]));
    let mut content = String::new();
    for (number, line) in lines.iter().enumerate() {
        let label = format!("line {number}");
        content.push_str(&label);
        content.push('\n');
        parser.documents.insert(label, line.clone());
    }
    let mut disk = DiskSpy::default();
    disk.add(&format!("{OWNERS}/{ID}.lock"), "");
    disk.add(&session_file(), &content);
    Sut {
        disk,
        programs: ProgramsSpy {
            answer: Ok(HOLDING_THE_SESSION.to_string()),
            runs: RefCell::default(),
        },
        parser,
        home: Some(Path::new("/home")),
    }
}

fn state_of(sut: &Sut) -> (State, SystemTime) {
    let agents = sut.harness().agents().unwrap();
    (agents[0].state.clone(), agents[0].since)
}

fn session_file() -> String {
    format!("{SESSIONS}/2026-11-19T10-00-00-000Z_{ID}.jsonl")
}

fn time(seconds: u64) -> SystemTime {
    SystemTime::UNIX_EPOCH + Duration::from_secs(seconds)
}

fn text(value: &str) -> Tree {
    Tree::Text(value.to_string())
}

fn fields<const N: usize>(pairs: [(&str, Tree); N]) -> Tree {
    Tree::Fields(
        pairs
            .into_iter()
            .map(|(name, value)| (name.to_string(), value))
            .collect(),
    )
}

fn at(seconds: u64) -> Tree {
    text(&format!(
        "1970-01-01T{:02}:{:02}:{:02}.000Z",
        seconds / 3600,
        seconds / 60 % 60,
        seconds % 60
    ))
}

fn lease(held: &[&str]) -> Tree {
    fields([("held", Tree::List(held.iter().map(|id| text(id)).collect()))])
}

fn unreadable() -> Tree {
    Tree::Missing
}

fn session_start() -> Tree {
    fields([
        ("type", text("session")),
        ("timestamp", at(1)),
        ("cwd", text("/work/pwe")),
    ])
}

fn title(value: &str) -> Tree {
    fields([("type", text("title")), ("title", text(value))])
}

fn message(timestamp: Tree, message: Tree) -> Tree {
    fields([
        ("type", text("message")),
        ("timestamp", timestamp),
        ("message", message),
    ])
}

fn user(seconds: u64) -> Tree {
    message(at(seconds), fields([("role", text("user"))]))
}

fn assistant(seconds: u64, stop: &str) -> Tree {
    message(
        at(seconds),
        fields([("role", text("assistant")), ("stopReason", text(stop))]),
    )
}

#[test]
fn a_live_session_is_listed_with_its_folder_session_and_title() {
    let sut = make_sut(&[
        title("Fix the login bug"),
        session_start(),
        user(2),
        assistant(3, "stop"),
    ]);
    let agents = sut.harness().agents().unwrap();
    assert_eq!(agents.len(), 1);
    assert_eq!(agents[0].folder, PathBuf::from("/work/pwe"));
    assert_eq!(agents[0].session.as_deref(), Some(ID));
    assert_eq!(agents[0].title.as_deref(), Some("Fix the login bug"));
    assert_eq!(
        *sut.programs.runs.borrow(),
        [Run {
            program: "omp".to_string(),
            arguments: ["session", "lease", "--json", "--", ID]
                .map(String::from)
                .to_vec(),
        }]
    );
}

#[test]
fn a_session_omp_no_longer_holds_is_neither_listed_nor_read() {
    let mut sut = make_sut(&[session_start(), user(2), assistant(3, "stop")]);
    sut.programs.answer = Ok(HOLDING_NOTHING.to_string());
    assert_eq!(sut.harness().agents(), Ok(vec![]));
    assert!(
        !sut.disk
            .calls
            .borrow()
            .contains(&DiskCall::Read(PathBuf::from(session_file())))
    );
}

#[test]
fn an_advisor_session_is_not_an_agent() {
    let mut sut = make_sut(&[]);
    sut.disk = DiskSpy::default();
    sut.disk.add(&format!("{OWNERS}/{ID}__advisor.lock"), "");
    assert_eq!(sut.harness().agents(), Ok(vec![]));
    assert!(sut.programs.runs.borrow().is_empty());
}

#[test]
fn without_sessions_omp_is_not_run() {
    let mut sut = make_sut(&[]);
    sut.disk = DiskSpy::default();
    assert_eq!(sut.harness().agents(), Ok(vec![]));
    assert!(sut.programs.runs.borrow().is_empty());
}

#[test]
fn a_lease_that_cannot_be_read_is_a_failure() {
    let mut sut = make_sut(&[session_start()]);
    sut.programs.answer = Err("omp: command not found".to_string());
    let failure = sut.harness().agents().unwrap_err();
    assert!(failure.contains("omp: command not found"), "{failure}");
}

#[test]
fn without_a_home_folder_omp_cannot_be_read() {
    let mut sut = make_sut(&[]);
    sut.home = None;
    let failure = sut.harness().agents().unwrap_err();
    assert!(failure.contains("home"), "{failure}");
}

#[test]
fn a_session_before_its_first_prompt_is_idle() {
    assert_eq!(
        state_of(&make_sut(&[session_start()])),
        (State::Idle, time(1))
    );
}

#[test]
fn a_finished_turn_is_finished() {
    assert_eq!(
        state_of(&make_sut(&[session_start(), user(2), assistant(3, "stop")])),
        (State::Finished, time(3))
    );
}

#[test]
fn a_line_the_parser_cannot_read_is_skipped() {
    let sut = make_sut(&[session_start(), user(2), assistant(3, "stop"), unreadable()]);
    assert_eq!(state_of(&sut), (State::Finished, time(3)));
}
