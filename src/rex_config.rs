#[cfg(test)]
mod tests;

pub trait RexConfig {
    fn loader(&self, pwe: &str) -> String;
    fn config(&self) -> &str;
}

pub struct EmbeddedRexConfig;

impl RexConfig for EmbeddedRexConfig {
    fn loader(&self, pwe: &str) -> String {
        format!(
            "local pwe = {}\n{}",
            lua_string(pwe),
            include_str!("../rex/loader.lua")
        )
    }

    fn config(&self) -> &str {
        include_str!("../rex/navigate.lua")
    }
}

fn lua_string(text: &str) -> String {
    let mut quoted = String::from('"');
    for character in text.chars() {
        match character {
            '"' => quoted.push_str("\\\""),
            '\\' => quoted.push_str("\\\\"),
            '\n' => quoted.push_str("\\n"),
            other => quoted.push(other),
        }
    }
    quoted.push('"');
    quoted
}
