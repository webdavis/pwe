use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub trait Disk {
    fn entries(&self, folder: &Path) -> Vec<PathBuf>;
    fn read(&self, file: &Path) -> Option<String>;
    fn created(&self, file: &Path) -> Option<SystemTime>;
}
