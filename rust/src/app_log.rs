use std::fs::OpenOptions;
use std::io::Write;

use anyhow::{Context, Result};
use chrono::{Local, SecondsFormat};

use crate::config_path::config_file_path;

const BACKEND_LOG_PREFIX: &str = "backend";

pub(crate) fn log_error(scope: &str, error: &anyhow::Error) {
    log_error_message(scope, &format!("{error:#}"), None);
}

pub(crate) fn log_error_message(scope: &str, message: &str, stack: Option<&str>) {
    let now = Local::now();
    let timestamp = now.to_rfc3339_opts(SecondsFormat::Millis, false);
    let date = now.format("%Y-%m-%d").to_string();
    let _ = append_error(scope, message, stack, &timestamp, &date);
}

fn append_error(
    scope: &str,
    message: &str,
    stack: Option<&str>,
    timestamp: &str,
    date: &str,
) -> Result<()> {
    let path = config_file_path(&format!("log/{BACKEND_LOG_PREFIX}-{date}.log"))?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("Failed to create log directory {}", parent.display()))?;
    }
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .with_context(|| format!("Failed to open log file {}", path.display()))?;
    writeln!(
        file,
        "{timestamp} ERROR {BACKEND_LOG_PREFIX} {}",
        sanitize_scope(scope)
    )?;
    writeln!(file, "{}", redact(message))?;
    if let Some(stack) = stack {
        writeln!(file, "{}", redact(stack))?;
    }
    Ok(())
}

fn sanitize_scope(scope: &str) -> String {
    scope
        .trim()
        .chars()
        .map(|ch| if ch.is_whitespace() { '_' } else { ch })
        .collect()
}

fn redact(value: &str) -> String {
    const KEYS: [&str; 4] = ["password", "passwd", "secret", "token"];
    let mut output = String::with_capacity(value.len());
    let mut index = 0;

    while index < value.len() {
        let remaining = &value[index..];
        let lower = remaining.to_lowercase();
        let Some((key, separator_index)) = KEYS.iter().find_map(|key| {
            if !starts_with_secret_key(&lower, key) {
                return None;
            }
            let after_key = &remaining[key.len()..];
            let trimmed = after_key.trim_start();
            let skipped = after_key.len() - trimmed.len();
            let separator = trimmed.chars().next()?;
            if separator == '=' || separator == ':' {
                Some((*key, key.len() + skipped))
            } else {
                None
            }
        }) else {
            let ch = remaining.chars().next().unwrap();
            output.push(ch);
            index += ch.len_utf8();
            continue;
        };

        output.push_str(&remaining[..key.len()]);
        output.push_str("=<redacted>");

        let after_separator = &remaining[separator_index + 1..];
        let skipped_whitespace = after_separator.len() - after_separator.trim_start().len();
        let value_start = separator_index + 1 + skipped_whitespace;
        let after_value_start = &remaining[value_start..];
        let value_len = match after_value_start.chars().next() {
            Some(quote @ ('\'' | '"')) => {
                quote.len_utf8()
                    + after_value_start[quote.len_utf8()..]
                        .find(quote)
                        .map(|end| end + quote.len_utf8())
                        .unwrap_or(after_value_start[quote.len_utf8()..].len())
            }
            Some(_) => after_value_start
                .find(|ch: char| ch.is_whitespace() || ch == ',' || ch == ';')
                .unwrap_or(after_value_start.len()),
            None => 0,
        };
        index += value_start + value_len;
    }

    output
}

fn starts_with_secret_key(value: &str, key: &str) -> bool {
    value.starts_with(key)
        && !value
            .chars()
            .nth(key.chars().count())
            .is_some_and(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

#[cfg(test)]
fn log_error_message_for_test(
    scope: &str,
    message: &str,
    stack: Option<&str>,
    timestamp: &str,
    date: &str,
) {
    let _ = append_error(scope, message, stack, timestamp, date);
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::Path};

    struct TestWorkspace {
        original_dir: std::path::PathBuf,
        temp_dir: tempfile::TempDir,
    }

    impl TestWorkspace {
        fn new() -> Self {
            let temp_dir = tempfile::tempdir().unwrap();
            let original_dir = env::current_dir().unwrap();
            env::set_current_dir(temp_dir.path()).unwrap();
            Self {
                original_dir,
                temp_dir,
            }
        }

        fn path(&self) -> &Path {
            self.temp_dir.path()
        }

        fn log_path(&self) -> std::path::PathBuf {
            self.path()
                .join("config")
                .join("log")
                .join("backend-2026-04-30.log")
        }
    }

    impl Drop for TestWorkspace {
        fn drop(&mut self) {
            env::set_current_dir(&self.original_dir).unwrap();
        }
    }

    #[test]
    fn writes_backend_errors_to_daily_log_file() {
        let _guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
        let workspace = TestWorkspace::new();

        super::log_error_message_for_test(
            "profile.list",
            "Failed to parse config password=secret",
            Some("stack line"),
            "2026-04-30T21:45:12.345+00:00",
            "2026-04-30",
        );

        let content = fs::read_to_string(workspace.log_path()).unwrap();
        assert!(content.contains("2026-04-30T21:45:12.345+00:00 ERROR backend profile.list"));
        assert!(content.contains("Failed to parse config password=<redacted>"));
        assert!(content.contains("stack line"));
        assert!(!content.contains("secret"));
    }

    #[test]
    fn redacts_quoted_secret_values_that_contain_spaces() {
        let _guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
        let workspace = TestWorkspace::new();

        super::log_error_message_for_test(
            "ssh.connect",
            "Connection failed password=\"alpha beta\" token: 'gamma delta'",
            None,
            "2026-04-30T21:45:12.345+00:00",
            "2026-04-30",
        );

        let content = fs::read_to_string(workspace.log_path()).unwrap();
        assert!(content.contains("password=<redacted>"));
        assert!(content.contains("token=<redacted>"));
        assert!(!content.contains("alpha"));
        assert!(!content.contains("beta"));
        assert!(!content.contains("gamma"));
        assert!(!content.contains("delta"));
    }

    #[test]
    fn logging_failures_do_not_panic() {
        let _guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
        let workspace = TestWorkspace::new();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(
            workspace.path().join("config").join("log"),
            "not a directory",
        )
        .unwrap();

        super::log_error_message_for_test(
            "theme.save",
            "Failed to write theme",
            None,
            "2026-04-30T21:45:12.345+00:00",
            "2026-04-30",
        );
    }
}
