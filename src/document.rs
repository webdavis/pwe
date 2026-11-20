pub trait Document {
    fn get(&self, name: &str) -> &dyn Document;
    fn text(&self) -> Option<&str>;
}
