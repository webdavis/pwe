use std::time::{Duration, SystemTime};

pub fn time_of(text: &str) -> Option<SystemTime> {
    let (_, clock) = text.split_once('T')?;
    let mut clock = clock.get(..8)?.split(':').map(str::parse::<u64>);
    let (hour, minute, second) = (
        clock.next()?.ok()?,
        clock.next()?.ok()?,
        clock.next()?.ok()?,
    );
    Some(SystemTime::UNIX_EPOCH + Duration::from_secs(hour * 3_600 + minute * 60 + second))
}
