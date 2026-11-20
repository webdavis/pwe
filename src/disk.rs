use std::path::{Path, PathBuf};
use std::time::SystemTime;

pub trait Disk {
    fn entries(&self, folder: &Path) -> Vec<PathBuf>;
    fn read(&self, file: &Path) -> Option<String>;
    fn created(&self, file: &Path) -> Option<SystemTime>;
}

pub struct LocalDisk;

impl Disk for LocalDisk {
    fn entries(&self, folder: &Path) -> Vec<PathBuf> {
        std::fs::read_dir(folder)
            .map(|entries| entries.flatten().map(|entry| entry.path()).collect())
            .unwrap_or_default()
    }

    fn read(&self, file: &Path) -> Option<String> {
        std::fs::read_to_string(file).ok()
    }

    fn created(&self, file: &Path) -> Option<SystemTime> {
        std::fs::metadata(file)
            .and_then(|metadata| metadata.created())
            .ok()
    }
}
