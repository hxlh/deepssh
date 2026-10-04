use std::{fs, sync::Mutex};

use anyhow::{Context, Result};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

use crate::config_path::config_file_path;

const CONFIG_FILE_NAME: &str = "theme_settings.yaml";

static THEME_STORE: Lazy<Mutex<ThemeStore>> = Lazy::new(|| Mutex::new(ThemeStore::default()));

#[flutter_rust_bridge::frb(ignore)]
#[derive(Default)]
struct ThemeStore {
    settings: Option<ThemeSettings>,
    initialized: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ThemeSettings {
    pub ui: UiTheme,
    pub terminal: TerminalTheme,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct UiTheme {
    pub preset_name: String,
    pub font_family: String,
    pub font_size: u32,
    pub normal_font_weight: u32,
    pub bold_font_weight: u32,
    pub background: String,
    pub panel: String,
    pub sidebar: String,
    pub accent: String,
    pub text_primary: String,
    pub text_muted: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TerminalTheme {
    pub preset_name: String,
    pub font_family: String,
    pub font_size: u32,
    pub normal_font_weight: u32,
    pub bold_font_weight: u32,
    pub cursor_style: String,
    pub cursor_blink: bool,
    pub foreground: String,
    pub terminal_background: String,
    pub selection_color: String,
    pub cursor_color: String,
    pub scrollback_lines: u32,
    pub regex_highlights: Vec<RegexHighlight>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RegexHighlight {
    pub pattern: String,
    pub color: String,
    pub note: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Deserialize, Serialize)]
struct ThemeFile {
    /// Missing on files written before the appearance refresh; those are the
    /// only ones eligible for the legacy-default upgrade.
    #[serde(default)]
    version: Option<u32>,
    ui: UiThemeConfig,
    terminal: TerminalThemeConfig,
}

fn default_ui_normal_font_weight() -> u32 {
    500
}

fn default_ui_bold_font_weight() -> u32 {
    700
}

fn default_terminal_normal_font_weight() -> u32 {
    400
}

fn default_terminal_bold_font_weight() -> u32 {
    700
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Deserialize, Serialize)]
struct UiThemeConfig {
    preset_name: String,
    font_family: String,
    font_size: u32,
    #[serde(default = "default_ui_normal_font_weight")]
    normal_font_weight: u32,
    #[serde(default = "default_ui_bold_font_weight")]
    bold_font_weight: u32,
    background: String,
    panel: String,
    sidebar: String,
    accent: String,
    text_primary: String,
    text_muted: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Deserialize, Serialize)]
struct TerminalThemeConfig {
    preset_name: String,
    font_family: String,
    font_size: u32,
    #[serde(default = "default_terminal_normal_font_weight")]
    normal_font_weight: u32,
    #[serde(default = "default_terminal_bold_font_weight")]
    bold_font_weight: u32,
    cursor_style: String,
    cursor_blink: bool,
    foreground: String,
    terminal_background: String,
    selection_color: String,
    cursor_color: String,
    scrollback_lines: u32,
    #[serde(default)]
    regex_highlights: Vec<RegexHighlightConfig>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Deserialize, Serialize)]
struct RegexHighlightConfig {
    pattern: String,
    color: String,
    #[serde(default)]
    note: String,
}

impl From<&ThemeSettings> for ThemeFile {
    fn from(settings: &ThemeSettings) -> Self {
        Self {
            version: Some(CURRENT_THEME_VERSION),
            ui: UiThemeConfig::from(&settings.ui),
            terminal: TerminalThemeConfig::from(&settings.terminal),
        }
    }
}

impl From<ThemeFile> for ThemeSettings {
    fn from(file: ThemeFile) -> Self {
        Self {
            ui: UiTheme::from(file.ui),
            terminal: TerminalTheme::from(file.terminal),
        }
    }
}

impl From<&UiTheme> for UiThemeConfig {
    fn from(theme: &UiTheme) -> Self {
        Self {
            preset_name: theme.preset_name.clone(),
            font_family: theme.font_family.clone(),
            font_size: theme.font_size,
            normal_font_weight: theme.normal_font_weight,
            bold_font_weight: theme.bold_font_weight,
            background: theme.background.clone(),
            panel: theme.panel.clone(),
            sidebar: theme.sidebar.clone(),
            accent: theme.accent.clone(),
            text_primary: theme.text_primary.clone(),
            text_muted: theme.text_muted.clone(),
        }
    }
}

impl From<UiThemeConfig> for UiTheme {
    fn from(config: UiThemeConfig) -> Self {
        Self {
            preset_name: config.preset_name,
            font_family: config.font_family,
            font_size: config.font_size,
            normal_font_weight: config.normal_font_weight,
            bold_font_weight: config.bold_font_weight,
            background: config.background,
            panel: config.panel,
            sidebar: config.sidebar,
            accent: config.accent,
            text_primary: config.text_primary,
            text_muted: config.text_muted,
        }
    }
}

impl From<&TerminalTheme> for TerminalThemeConfig {
    fn from(theme: &TerminalTheme) -> Self {
        Self {
            preset_name: theme.preset_name.clone(),
            font_family: theme.font_family.clone(),
            font_size: theme.font_size,
            normal_font_weight: theme.normal_font_weight,
            bold_font_weight: theme.bold_font_weight,
            cursor_style: theme.cursor_style.clone(),
            cursor_blink: theme.cursor_blink,
            foreground: theme.foreground.clone(),
            terminal_background: theme.terminal_background.clone(),
            selection_color: theme.selection_color.clone(),
            cursor_color: theme.cursor_color.clone(),
            scrollback_lines: theme.scrollback_lines,
            regex_highlights: theme
                .regex_highlights
                .iter()
                .map(RegexHighlightConfig::from)
                .collect(),
        }
    }
}

impl From<TerminalThemeConfig> for TerminalTheme {
    fn from(config: TerminalThemeConfig) -> Self {
        Self {
            preset_name: config.preset_name,
            font_family: config.font_family,
            font_size: config.font_size,
            normal_font_weight: config.normal_font_weight,
            bold_font_weight: config.bold_font_weight,
            cursor_style: config.cursor_style,
            cursor_blink: config.cursor_blink,
            foreground: config.foreground,
            terminal_background: config.terminal_background,
            selection_color: config.selection_color,
            cursor_color: config.cursor_color,
            scrollback_lines: config.scrollback_lines,
            regex_highlights: config
                .regex_highlights
                .into_iter()
                .map(RegexHighlight::from)
                .collect(),
        }
    }
}

impl From<&RegexHighlight> for RegexHighlightConfig {
    fn from(value: &RegexHighlight) -> Self {
        Self {
            pattern: value.pattern.clone(),
            color: value.color.clone(),
            note: value.note.clone(),
        }
    }
}

impl From<RegexHighlightConfig> for RegexHighlight {
    fn from(config: RegexHighlightConfig) -> Self {
        Self {
            pattern: config.pattern,
            color: config.color,
            note: config.note,
        }
    }
}

const CURRENT_THEME_VERSION: u32 = 2;

/// Prototype defaults: `design/deepssh-prototype.html` `:root` plus the regex
/// set the user ships (also mirrored in Dart `TerminalThemeSettings.commandDeck`).
fn default_theme() -> ThemeSettings {
    ThemeSettings {
        ui: UiTheme {
            preset_name: "Command Deck".to_string(),
            // Empty = platform UI font, the prototype's 「系统默认（含中文）」.
            font_family: String::new(),
            font_size: 13,
            normal_font_weight: default_ui_normal_font_weight(),
            bold_font_weight: default_ui_bold_font_weight(),
            background: "#FAF9F5".to_string(),
            panel: "#FFFFFF".to_string(),
            sidebar: "#FAF9F5".to_string(),
            accent: "#D97757".to_string(),
            text_primary: "#1F1E1D".to_string(),
            text_muted: "#6B6862".to_string(),
        },
        terminal: TerminalTheme {
            preset_name: "Command Deck".to_string(),
            font_family: "JetBrains Mono".to_string(),
            font_size: 14,
            normal_font_weight: default_terminal_normal_font_weight(),
            bold_font_weight: default_terminal_bold_font_weight(),
            cursor_style: "bar".to_string(),
            cursor_blink: true,
            foreground: "#DEDCD6".to_string(),
            terminal_background: "#17181A".to_string(),
            // Prototype 终端配色: 高亮 #D9A24B, 光标 #8FBF7F.
            selection_color: "#D9A24B".to_string(),
            cursor_color: "#8FBF7F".to_string(),
            scrollback_lines: 10000,
            regex_highlights: vec![
                RegexHighlight {
                    pattern: r"[dlbcps-]([r-][w-][xs-]){3}|\broot\b|\bsudo\b|\bchmod\b|\bchown\b"
                        .to_string(),
                    color: "#C1794F".to_string(),
                    note: "Linux权限与用户".to_string(),
                },
                RegexHighlight {
                    pattern: r"(?:^|\s)(?:/[^\s]*|\./[^\s]*|\.\./[^\s]*|~[^\s]*)"
                        .to_string(),
                    color: "#E0C828".to_string(),
                    note: "Linux文件路径".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|return|exit|break|continue)\b"
                        .to_string(),
                    color: "#FF1495".to_string(),
                    note: "Shell关键字与流程控制".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b(SUCCESS|PASS|OK|DONE|COMPLETE|ERROR|FAIL|FAILED|FATAL|CRITICAL)\b|✓|✗|❌|✅"
                        .to_string(),
                    color: "#1EBF19".to_string(),
                    note: "成功/错误状态".to_string(),
                },
                RegexHighlight {
                    pattern: r"https?://[^\s]+|ftp://[^\s]+|www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?"
                        .to_string(),
                    color: "#3F8EE8".to_string(),
                    note: "网址链接".to_string(),
                },
                RegexHighlight {
                    pattern: r#""[^"]*"|'[^']*'|`[^`]*`"#.to_string(),
                    color: "#5E923D".to_string(),
                    note: "字符串与引号".to_string(),
                },
                RegexHighlight {
                    pattern: r"\$[A-Za-z_][A-Za-z0-9_]*|--?[A-Za-z][A-Za-z0-9-]*"
                        .to_string(),
                    color: "#CC703A".to_string(),
                    note: "环境变量与参数".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b|\b(?:localhost|127\.0\.0\.1)\b"
                        .to_string(),
                    color: "#459BFF".to_string(),
                    note: "网络与IP地址".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}(?::\d{2})?\b|\b\d{2}:\d{2}(?::\d{2})?\b"
                        .to_string(),
                    color: "#7960FF".to_string(),
                    note: "时间与日期".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b\d+(?:\.\d+)?\s*(?:[KMGT]i?B|%|MB|GB|KB)?\b"
                        .to_string(),
                    color: "#1AA416".to_string(),
                    note: "数字与计数".to_string(),
                },
            ],
        },
    }
}

/// The pre-prototype shipped theme. Files saved before the appearance refresh
/// are compared against this; an untouched file is upgraded in place instead of
/// keeping the old 7-rule set forever.
fn legacy_default_theme() -> ThemeSettings {
    ThemeSettings {
        ui: UiTheme {
            preset_name: "Command Deck".to_string(),
            font_family: "Inter".to_string(),
            font_size: 14,
            normal_font_weight: default_ui_normal_font_weight(),
            bold_font_weight: default_ui_bold_font_weight(),
            background: "#FAF9F5".to_string(),
            panel: "#FFFFFF".to_string(),
            sidebar: "#FAF9F5".to_string(),
            accent: "#D97757".to_string(),
            text_primary: "#1F1E1D".to_string(),
            text_muted: "#6B6862".to_string(),
        },
        terminal: TerminalTheme {
            preset_name: "Command Deck".to_string(),
            font_family: "JetBrains Mono".to_string(),
            font_size: 14,
            normal_font_weight: default_terminal_normal_font_weight(),
            bold_font_weight: default_terminal_bold_font_weight(),
            cursor_style: "bar".to_string(),
            cursor_blink: true,
            foreground: "#DEDCD6".to_string(),
            terminal_background: "#17181A".to_string(),
            selection_color: "#3A3F44".to_string(),
            cursor_color: "#D9A24B".to_string(),
            scrollback_lines: 10000,
            regex_highlights: vec![
                RegexHighlight {
                    pattern: "ERROR|FATAL|Exception|Traceback".to_string(),
                    color: "#F14C4C".to_string(),
                    note: "错误日志".to_string(),
                },
                RegexHighlight {
                    pattern: "WARN|WARNING".to_string(),
                    color: "#F5F543".to_string(),
                    note: "警告日志".to_string(),
                },
                RegexHighlight {
                    pattern: "SUCCESS|OK|DONE".to_string(),
                    color: "#23D18B".to_string(),
                    note: "成功状态".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b[45]\d\d\b".to_string(),
                    color: "#F14C4C".to_string(),
                    note: "HTTP 错误".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b\d+ms\b|\b\d+\.\d+s\b".to_string(),
                    color: "#29B8DB".to_string(),
                    note: "耗时".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b(?:\d{1,3}\.){3}\d{1,3}\b".to_string(),
                    color: "#D670D6".to_string(),
                    note: "IP 地址".to_string(),
                },
                RegexHighlight {
                    pattern: r"\b[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\b"
                        .to_string(),
                    color: "#3B8EEA".to_string(),
                    note: "UUID".to_string(),
                },
            ],
        },
    }
}

fn load_theme_from_disk() -> Result<ThemeSettings> {
    let path = config_file_path(CONFIG_FILE_NAME)?;
    let content = match fs::read_to_string(&path) {
        Ok(content) => content,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(default_theme()),
        Err(error) => {
            return Err(error).with_context(|| format!("Failed to read {}", path.display()))
        }
    };
    let file: ThemeFile = serde_yaml::from_str(&content)
        .with_context(|| format!("Failed to parse {}", path.display()))?;
    let version = file.version.unwrap_or(0);
    let settings = ThemeSettings::from(file);
    if version < CURRENT_THEME_VERSION {
        // An untouched pre-refresh file still carries the old seven-rule set
        // and the old terminal cursor colours; upgrade it to the prototype
        // defaults instead of showing rules the user replaced.
        if settings == legacy_default_theme() {
            return Ok(default_theme());
        }
        // The prototype picker only ships Command Deck. Files still sitting on
        // the removed built-ins fall back to it instead of reappearing as an
        // unsupported preset.
        let removed_preset = matches!(settings.ui.preset_name.as_str(), "VS Code Dark")
            || matches!(
                settings.terminal.preset_name.as_str(),
                "One Dark" | "Solarized"
            );
        if removed_preset {
            return Ok(default_theme());
        }
    }
    Ok(settings)
}

fn write_theme_to_disk(settings: &ThemeSettings) -> Result<()> {
    let path = config_file_path(CONFIG_FILE_NAME)?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("Failed to create {parent:?}"))?;
    }
    let file = ThemeFile::from(settings);
    let content = serde_yaml::to_string(&file).context("Failed to serialize theme settings")?;
    fs::write(&path, content).with_context(|| format!("Failed to write {}", path.display()))?;
    Ok(())
}

fn ensure_theme_loaded(store: &mut ThemeStore) -> Result<()> {
    if store.initialized {
        return Ok(());
    }
    store.settings = Some(load_theme_from_disk()?);
    store.initialized = true;
    Ok(())
}

pub fn load_theme() -> Result<ThemeSettings> {
    let result = (|| {
        let mut store = THEME_STORE.lock().unwrap();
        ensure_theme_loaded(&mut store)?;
        Ok(store
            .settings
            .clone()
            .expect("Theme settings should be initialized"))
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("theme.load", error);
    }
    result
}

pub fn save_theme(settings: ThemeSettings) -> Result<()> {
    let result = (|| {
        let mut store = THEME_STORE.lock().unwrap();
        write_theme_to_disk(&settings)?;
        store.settings = Some(settings);
        store.initialized = true;
        Ok(())
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("theme.save", error);
    }
    result
}

#[cfg(test)]
fn clear_theme_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
    let mut store = THEME_STORE.lock().unwrap();
    store.settings = None;
    store.initialized = false;
    guard
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::Path};

    use super::*;

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

        fn config_path(&self) -> std::path::PathBuf {
            self.path().join("config").join("theme_settings.yaml")
        }

        fn log_dir(&self) -> std::path::PathBuf {
            self.path().join("config").join("log")
        }
    }

    impl Drop for TestWorkspace {
        fn drop(&mut self) {
            env::set_current_dir(&self.original_dir).unwrap();
        }
    }

    fn reset_store() {
        let mut store = THEME_STORE.lock().unwrap();
        store.settings = None;
        store.initialized = false;
    }

    fn sample_theme() -> ThemeSettings {
        ThemeSettings {
            ui: UiTheme {
                preset_name: "Custom".to_string(),
                font_family: "Roboto".to_string(),
                font_size: 16,
                normal_font_weight: 300,
                bold_font_weight: 800,
                background: "#000000".to_string(),
                panel: "#111111".to_string(),
                sidebar: "#222222".to_string(),
                accent: "#FF00FF".to_string(),
                text_primary: "#FFFFFF".to_string(),
                text_muted: "#AAAAAA".to_string(),
            },
            terminal: TerminalTheme {
                preset_name: "Custom Term".to_string(),
                font_family: "Fira Code".to_string(),
                font_size: 18,
                normal_font_weight: 400,
                bold_font_weight: 900,
                cursor_style: "block".to_string(),
                cursor_blink: false,
                foreground: "#CCCCCC".to_string(),
                terminal_background: "#000010".to_string(),
                selection_color: "#333355".to_string(),
                cursor_color: "#FFAA00".to_string(),
                scrollback_lines: 5000,
                regex_highlights: vec![RegexHighlight {
                    pattern: "FAIL".to_string(),
                    color: "#FF0000".to_string(),
                    note: "错误日志".to_string(),
                }],
            },
        }
    }

    #[test]
    fn missing_yaml_file_returns_defaults() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();

        let theme = load_theme().unwrap();

        assert_eq!(theme.ui.preset_name, "Command Deck");
        assert_eq!(theme.terminal.preset_name, "Command Deck");
        assert!(!workspace.config_path().exists());
    }

    #[test]
    fn save_persists_to_yaml() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();

        save_theme(sample_theme()).unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(yaml.contains("preset_name: Custom"));
        assert!(yaml.contains("font_family: Roboto"));
        assert!(yaml.contains("font_size: 16"));
        assert!(yaml.contains("normal_font_weight: 300"));
        assert!(yaml.contains("bold_font_weight: 800"));
        assert!(yaml.contains("normal_font_weight: 400"));
        assert!(yaml.contains("bold_font_weight: 900"));
        assert!(yaml.contains("background: '#000000'"));
        assert!(yaml.contains("cursor_style: block"));
        assert!(yaml.contains("cursor_blink: false"));
        assert!(yaml.contains("scrollback_lines: 5000"));
        assert!(yaml.contains("pattern: FAIL"));
    }

    #[test]
    fn legacy_default_file_is_upgraded_to_prototype_defaults() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        let legacy = legacy_default_theme();
        let file = ThemeFile {
            version: None,
            ui: UiThemeConfig::from(&legacy.ui),
            terminal: TerminalThemeConfig::from(&legacy.terminal),
        };
        fs::write(
            workspace.config_path(),
            serde_yaml::to_string(&file).unwrap(),
        )
        .unwrap();

        let theme = load_theme().unwrap();

        assert_eq!(theme, default_theme());
        assert_eq!(theme.terminal.regex_highlights.len(), 10);
    }

    #[test]
    fn removed_built_in_presets_fall_back_to_command_deck() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        let mut old = sample_theme();
        old.ui.preset_name = "VS Code Dark".to_string();
        old.terminal.preset_name = "One Dark".to_string();
        let file = ThemeFile {
            version: None,
            ui: UiThemeConfig::from(&old.ui),
            terminal: TerminalThemeConfig::from(&old.terminal),
        };
        fs::write(
            workspace.config_path(),
            serde_yaml::to_string(&file).unwrap(),
        )
        .unwrap();

        let theme = load_theme().unwrap();

        assert_eq!(theme.ui.preset_name, "Command Deck");
        assert_eq!(theme.terminal.preset_name, "Command Deck");
    }

    #[test]
    fn missing_font_weights_default_by_theme_section() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(
            workspace.config_path(),
            r##"ui:
  preset_name: Legacy UI
  font_family: Inter
  font_size: 14
  background: '#1E1E1E'
  panel: '#252526'
  sidebar: '#181818'
  accent: '#3794FF'
  text_primary: '#E6E6E6'
  text_muted: '#9D9D9D'
terminal:
  preset_name: Legacy Terminal
  font_family: Maple Mono NF CN
  font_size: 14
  cursor_style: block
  cursor_blink: true
  foreground: '#E6E6E6'
  terminal_background: '#252526'
  selection_color: '#094771'
  cursor_color: '#3794FF'
  scrollback_lines: 10000
"##,
        )
        .unwrap();

        let theme = load_theme().unwrap();

        assert_eq!(theme.ui.normal_font_weight, 500);
        assert_eq!(theme.ui.bold_font_weight, 700);
        assert_eq!(theme.terminal.normal_font_weight, 400);
        assert_eq!(theme.terminal.bold_font_weight, 700);
    }

    #[test]
    fn load_returns_persisted_theme() {
        let _guard = clear_theme_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();
        let original = sample_theme();
        save_theme(original.clone()).unwrap();
        reset_store();

        let loaded = load_theme().unwrap();

        assert_eq!(loaded, original);
    }

    #[test]
    fn save_overwrites_existing_yaml() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        save_theme(sample_theme()).unwrap();

        let mut updated = sample_theme();
        updated.ui.preset_name = "Updated".to_string();
        updated.ui.background = "#123456".to_string();
        save_theme(updated).unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(yaml.contains("preset_name: Updated"));
        assert!(yaml.contains("background: '#123456'"));
        assert!(!yaml.contains("preset_name: Custom\n"));
    }

    #[test]
    fn logs_theme_load_errors() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(workspace.config_path(), "ui: [").unwrap();

        let result = load_theme();

        assert!(result.is_err());
        let log_file = fs::read_dir(workspace.log_dir())
            .unwrap()
            .next()
            .unwrap()
            .unwrap()
            .path();
        let log = fs::read_to_string(log_file).unwrap();
        assert!(log.contains("ERROR backend theme.load"));
        assert!(log.contains("Failed to parse"));
    }

    #[test]
    fn invalid_yaml_returns_error_and_preserves_file() {
        let _guard = clear_theme_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(workspace.config_path(), "ui: [").unwrap();

        let result = load_theme();

        assert!(result.is_err());
        assert_eq!(
            fs::read_to_string(workspace.config_path()).unwrap(),
            "ui: ["
        );
    }
}
