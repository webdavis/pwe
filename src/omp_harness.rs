mod session;
#[cfg(test)]
mod tests;
mod time;

use crate::disk::Disk;
use crate::json_parser::JsonParser;
use crate::programs::Programs;
use agent::{Agent, Harness};
use std::collections::HashSet;
use std::path::{Path, PathBuf};

pub struct OmpHarness<'a> {
    pub disk: &'a dyn Disk,
    pub programs: &'a dyn Programs,
    pub parser: &'a dyn JsonParser,
    pub home: Option<&'a Path>,
}

impl Harness for OmpHarness<'_> {
    fn name(&self) -> &'static str {
        "omp"
    }

    fn agents(&self) -> Result<Vec<Agent>, String> {
        let omp = self.home.ok_or("cannot tell the home folder")?.join(".omp");
        let ids = self.session_ids(&omp);
        if ids.is_empty() {
            return Ok(Vec::new());
        }
        let live = self.live(&ids)?;
        Ok(self
            .session_files(&omp)
            .into_iter()
            .filter(|(id, _)| live.contains(id))
            .filter_map(|(id, file)| self.agent(id, &file))
            .collect())
    }
}

impl OmpHarness<'_> {
    fn session_ids(&self, omp: &Path) -> Vec<String> {
        self.disk
            .entries(&omp.join("run/session-owners"))
            .iter()
            .filter_map(|lock| lock.file_name()?.to_str()?.strip_suffix(".lock"))
            .filter(|id| !id.ends_with("__advisor"))
            .map(str::to_string)
            .collect()
    }

    fn live(&self, ids: &[String]) -> Result<HashSet<String>, String> {
        let mut arguments = vec!["session", "lease", "--json", "--"];
        arguments.extend(ids.iter().map(String::as_str));
        let answer = self
            .programs
            .run("omp", &arguments)
            .map_err(|error| format!("cannot ask omp which sessions are live: {error}"))?;
        let answer = self
            .parser
            .parse(&answer)
            .ok_or("cannot read omp's list of live sessions".to_string())?;
        Ok(answer
            .get("held")
            .items()
            .filter_map(|id| id.text().map(str::to_string))
            .collect())
    }

    fn session_files(&self, omp: &Path) -> Vec<(String, PathBuf)> {
        self.disk
            .entries(&omp.join("agent/sessions"))
            .iter()
            .flat_map(|project| self.disk.entries(project))
            .filter_map(|file| {
                let name = file.file_name()?.to_str()?.strip_suffix(".jsonl")?;
                let (_, id) = name.rsplit_once('_')?;
                Some((id.to_string(), file.clone()))
            })
            .collect()
    }

    fn agent(&self, id: String, file: &Path) -> Option<Agent> {
        let session = session::read(&self.disk.read(file)?, self.parser)?;
        let mut agent = Agent::new(session.folder, session.state, session.since);
        agent.session = Some(id);
        agent.title = session.title;
        Some(agent)
    }
}
