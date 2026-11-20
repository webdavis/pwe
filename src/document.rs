pub trait Document {
    fn get(&self, name: &str) -> &dyn Document;
    fn text(&self) -> Option<&str>;
    fn items(&self) -> Box<dyn Iterator<Item = &dyn Document> + '_>;
}
