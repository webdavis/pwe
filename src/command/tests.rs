use super::{Answer, Command, Commands};

struct FakeCommand {
    noun: &'static str,
    usage: &'static str,
    examples: &'static str,
}

impl Command for FakeCommand {
    fn noun(&self) -> &'static str {
        self.noun
    }

    fn usage(&self) -> &'static str {
        self.usage
    }

    fn examples(&self) -> &'static str {
        self.examples
    }

    fn run(&self, words: &[&str]) -> Option<Answer> {
        match words {
            ["peel"] => Some(Answer::success(format!("peeled a {}", self.noun))),
            _ => None,
        }
    }
}

const FRUIT: FakeCommand = FakeCommand {
    noun: "fruit",
    usage: "  pwe fruit peel   Peel the fruit\n",
    examples: "  pwe fruit peel\n",
};

const NUT: FakeCommand = FakeCommand {
    noun: "nut",
    usage: "  pwe nut peel     Peel the nut\n",
    examples: "  pwe nut peel\n",
};

fn run(arguments: &[&str]) -> Answer {
    let arguments: Vec<String> = arguments.iter().map(|word| word.to_string()).collect();
    Commands {
        nouns: &[&FRUIT, &NUT],
    }
    .run(&arguments)
}

#[test]
fn the_noun_named_first_answers_the_words_after_it() {
    assert_eq!(
        run(&["nut", "peel"]),
        Answer::success("peeled a nut".to_string())
    );
}

#[test]
fn help_is_printed_on_request_at_every_depth() {
    for arguments in [
        &[][..],
        &["help"],
        &["help", "fruit"],
        &["-h"],
        &["--help"],
        &["fruit", "--help"],
        &["fruit", "peel", "-h"],
        &["-h", "fruit"],
        &["fruit", "--help", "peel"],
        &["nonsense", "-h", "more"],
    ] {
        let answer = run(arguments);
        assert_eq!(answer.exit_code, 0, "{arguments:?}: {answer:?}");
        assert!(
            answer.output.contains("Examples:"),
            "{arguments:?}: {answer:?}"
        );
    }
}

#[test]
fn help_lists_every_noun_in_order_and_the_help_command() {
    let help = run(&["help"]).output;
    let usage = help.find("Usage:").unwrap();
    let fruit = help.find("pwe fruit peel   Peel the fruit").unwrap();
    let nut = help.find("pwe nut peel     Peel the nut").unwrap();
    let help_command = help.find("pwe help").unwrap();
    let examples = help.find("Examples:").unwrap();
    assert!(
        usage < fruit && fruit < nut && nut < help_command && help_command < examples,
        "{help}"
    );
    assert!(
        help[examples..].contains("  pwe fruit peel\n  pwe nut peel\n"),
        "{help}"
    );
}

#[test]
fn a_command_pwe_does_not_have_is_a_usage_failure_that_names_it_and_the_way_out() {
    for arguments in [
        &["fruit"][..],
        &["fruit", "eat"],
        &["fruit", "peel", "extra"],
        &["navigate"],
    ] {
        let answer = run(arguments);
        assert_eq!(answer.exit_code, 2, "{arguments:?}");
        assert_eq!(answer.output, "", "{arguments:?}");
        assert!(
            answer.error.contains(&arguments.join(" ")),
            "{arguments:?}: {answer:?}"
        );
        assert!(
            answer.error.contains("Run: pwe help"),
            "{arguments:?}: {answer:?}"
        );
    }
}
