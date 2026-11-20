pub trait Programs {
    fn run(&self, program: &str, arguments: &[&str]) -> Result<String, String>;
}
