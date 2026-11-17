#[cfg(test)]
mod tests;

pub trait RexConfig {
    fn loader(&self, pwe: &str) -> String;
    fn config(&self) -> String;
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

    fn config(&self) -> String {
        format!(
            "local sources = {{ watch = {}, record = {}, front = {}, navigate = {}, last_pane = {}, watcher = {} }}\n{}",
            lua_string(include_str!("../rex/watch.lua")),
            lua_string(include_str!("../rex/record.lua")),
            lua_string(include_str!("../rex/front.lua")),
            lua_string(include_str!("../rex/navigate.lua")),
            lua_string(include_str!("../rex/last_pane.lua")),
            lua_string(include_str!("../rex/watcher.lua")),
            include_str!("../rex/config.lua")
        )
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
