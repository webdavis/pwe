use std::path::{Path, PathBuf};

pub trait Disk {
    fn entries(&self, folder: &Path) -> Vec<PathBuf>;
    fn read(&self, file: &Path) -> Option<String>;
}
