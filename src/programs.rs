use std::process::Command;

pub trait Programs {
    fn run(&self, program: &str, arguments: &[&str]) -> Result<String, String>;
}

pub struct LocalPrograms;

impl Programs for LocalPrograms {
    fn run(&self, program: &str, arguments: &[&str]) -> Result<String, String> {
        let output = Command::new(program)
            .args(arguments)
            .output()
            .map_err(|error| format!("cannot run {program}: {error}"))?;
        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).into_owned())
        } else {
            Err(String::from_utf8_lossy(&output.stderr).trim().to_string())
        }
    }
}
