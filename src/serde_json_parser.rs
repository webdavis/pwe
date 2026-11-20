#[cfg(test)]
mod tests;

use crate::document::Document;
use crate::json_parser::JsonParser;
use serde_json::Value;

pub struct SerdeJsonParser;

impl JsonParser for SerdeJsonParser {
    fn parse(&self, text: &str) -> Option<Box<dyn Document>> {
        let value: Value = serde_json::from_str(text).unwrap();
        Some(Box::new(value))
    }
}

impl Document for Value {
    fn get(&self, name: &str) -> &dyn Document {
        self.get(name).unwrap()
    }

    fn text(&self) -> Option<&str> {
        Some(self.as_str().unwrap())
    }
}
