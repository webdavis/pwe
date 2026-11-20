use super::SerdeJsonParser;
use crate::json_parser::JsonParser;

fn make_sut() -> SerdeJsonParser {
    SerdeJsonParser
}

#[test]
fn reads_a_fields_text() {
    let document = make_sut().parse(r#"{"cwd":"/work/pwe"}"#).unwrap();
    assert_eq!(document.get("cwd").text(), Some("/work/pwe"));
}

#[test]
fn a_missing_field_has_no_text_even_several_steps_deep() {
    let document = make_sut().parse(r#"{"message":{"role":"user"}}"#).unwrap();
    assert_eq!(document.get("title").text(), None);
    assert_eq!(document.get("title").get("v").get("x").text(), None);
    assert_eq!(document.get("message").get("role").get("x").text(), None);
}

#[test]
fn a_field_that_is_not_text_has_no_text() {
    let document = make_sut()
        .parse(r#"{"v":1,"content":[],"message":{},"done":true,"error":null}"#)
        .unwrap();
    for name in ["v", "content", "message", "done", "error"] {
        assert_eq!(document.get(name).text(), None, "{name}");
    }
}

#[test]
fn walks_a_lists_items_in_order() {
    let document = make_sut().parse(r#"{"held":["a","b","c"]}"#).unwrap();
    let held: Vec<_> = document
        .get("held")
        .items()
        .map(|item| item.text())
        .collect();
    assert_eq!(held, [Some("a"), Some("b"), Some("c")]);
}
