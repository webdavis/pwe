use std::time::{Duration, SystemTime};

pub fn time_of(text: &str) -> Option<SystemTime> {
    let (date, clock) = text.strip_suffix('Z')?.split_once('T')?;
    let mut date = date.split('-').map(str::parse::<i64>);
    let (year, month, day) = (date.next()?.ok()?, date.next()?.ok()?, date.next()?.ok()?);
    let (clock, fraction) = clock.split_once('.').unwrap_or((clock, "0"));
    let mut clock = clock.split(':').map(str::parse::<u64>);
    let (hour, minute, second) = (
        clock.next()?.ok()?,
        clock.next()?.ok()?,
        clock.next()?.ok()?,
    );
    let millis: u64 = format!("{fraction:0<3}").get(..3)?.parse().ok()?;
    let days = u64::try_from(days_since_1970(year, month, day)).ok()?;
    let seconds = days * 86_400 + hour * 3_600 + minute * 60 + second;
    Some(SystemTime::UNIX_EPOCH + Duration::from_millis(seconds * 1_000 + millis))
}

fn days_since_1970(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let year_of_era = year - era * 400;
    let day_of_year = (153 * ((month + 9) % 12) + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    era * 146_097 + day_of_era - 719_468
}
