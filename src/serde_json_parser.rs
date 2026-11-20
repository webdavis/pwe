#[cfg(test)]
mod tests;

use crate::document::Document;
use crate::json_parser::JsonParser;
use serde_json::Value;

pub struct SerdeJsonParser;

impl JsonParser for SerdeJsonParser {
    fn parse(&self, text: &str) -> Option<Box<dyn Document>> {
        let value: Value = serde_json::from_str(text).ok()?;
        Some(Box::new(value))
    }
}

impl Document for Value {
    fn get(&self, name: &str) -> &dyn Document {
        &self[name]
    }

    fn text(&self) -> Option<&str> {
        self.as_str()
    }

    fn items(&self) -> Box<dyn Iterator<Item = &dyn Document> + '_> {
        Box::new(
            self.as_array()
                .into_iter()
                .flatten()
                .map(|item| item as &dyn Document),
        )
    }
}
