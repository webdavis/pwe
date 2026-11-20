use crate::document::Document;

pub trait JsonParser {
    fn parse(&self, text: &str) -> Option<Box<dyn Document>>;
}
