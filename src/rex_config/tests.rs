use super::{EmbeddedRexConfig, RexConfig};

#[test]
fn the_loader_opens_with_where_pwe_is() {
    let loader = EmbeddedRexConfig.loader("/Users/someone/.cargo/bin/pwe");
    assert!(
        loader.starts_with("local pwe = \"/Users/someone/.cargo/bin/pwe\"\n"),
        "{loader}"
    );
}

#[test]
fn a_path_with_a_quote_or_a_backslash_stays_one_lua_string() {
    let loader = EmbeddedRexConfig.loader(r#"/odd "folder"\pwe"#);
    assert!(
        loader.starts_with("local pwe = \"/odd \\\"folder\\\"\\\\pwe\"\n"),
        "{loader}"
    );
}

#[test]
fn a_path_with_a_line_break_stays_on_one_line() {
    let loader = EmbeddedRexConfig.loader("/odd\nfolder/pwe");
    assert!(
        loader.starts_with("local pwe = \"/odd\\nfolder/pwe\"\n"),
        "{loader}"
    );
}

#[test]
fn each_lua_source_in_the_config_stays_inside_its_own_string() {
    let config = EmbeddedRexConfig.config();
    let sources = config.lines().next().unwrap();
    assert!(
        sources.starts_with("local sources = { watch = \""),
        "{sources}"
    );
    assert!(sources.ends_with("\" }"), "{sources}");
}
