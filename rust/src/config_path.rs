#[cfg(any(target_os = "macos", test))]
use std::ffi::OsString;
use std::path::{Path, PathBuf};

#[cfg(any(target_os = "macos", test))]
use anyhow::anyhow;
use anyhow::Result;

pub(crate) fn config_file_path(file_name: &str) -> Result<PathBuf> {
    #[cfg(all(target_os = "macos", not(test)))]
    {
        macos_config_file_path(file_name, std::env::var_os("HOME"))
    }

    #[cfg(any(not(target_os = "macos"), test))]
    {
        Ok(relative_config_file_path(file_name))
    }
}

fn relative_config_file_path(file_name: &str) -> PathBuf {
    Path::new("config").join(file_name)
}

#[cfg(any(target_os = "macos", test))]
fn macos_config_file_path(file_name: &str, home_dir: Option<OsString>) -> Result<PathBuf> {
    let home_dir = home_dir.ok_or_else(|| anyhow!("Failed to resolve macOS home directory"))?;
    Ok(PathBuf::from(home_dir)
        .join("Library")
        .join("Application Support")
        .join("deepssh")
        .join(file_name))
}

#[cfg(test)]
mod tests {
    use std::{ffi::OsString, path::PathBuf};

    use super::*;

    #[test]
    fn non_macos_config_file_path_uses_relative_config_directory() {
        assert_eq!(
            relative_config_file_path("ssh_profiles.yaml"),
            PathBuf::from("config").join("ssh_profiles.yaml")
        );
    }

    #[test]
    fn macos_config_file_path_uses_application_support_directory() {
        assert_eq!(
            macos_config_file_path("theme_settings.yaml", Some(OsString::from("/Users/alex")))
                .unwrap(),
            PathBuf::from("/Users/alex")
                .join("Library")
                .join("Application Support")
                .join("deepssh")
                .join("theme_settings.yaml")
        );
    }

    #[test]
    fn macos_config_file_path_errors_when_home_is_missing() {
        let error = macos_config_file_path("theme_settings.yaml", None).unwrap_err();

        assert_eq!(error.to_string(), "Failed to resolve macOS home directory");
    }
}
