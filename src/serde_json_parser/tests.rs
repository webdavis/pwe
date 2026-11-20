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
