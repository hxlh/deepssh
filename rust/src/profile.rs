use std::{fs, path::Path, sync::Mutex};

use anyhow::{anyhow, Context, Result};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

const CONFIG_PATH: &str = "config/ssh_profiles.yaml";

static PROFILE_STORE: Lazy<Mutex<ProfileStore>> = Lazy::new(|| Mutex::new(ProfileStore::default()));

#[flutter_rust_bridge::frb(ignore)]
#[derive(Default)]
struct ProfileStore {
    profiles: Vec<SshProfile>,
    initialized: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SshProfile {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub password: String,
    pub term_type: String,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize, Serialize)]
struct SshProfilesFile {
    #[serde(default)]
    profiles: Vec<SshProfileConfig>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
struct SshProfileConfig {
    name: String,
    host: String,
    port: u16,
    username: String,
    password: String,
    #[serde(default = "default_term_type")]
    term_type: String,
}

fn default_term_type() -> String {
    "xterm-256color".to_string()
}

impl SshProfileConfig {
    fn into_profile(self) -> SshProfile {
        SshProfile {
            id: Uuid::new_v4().to_string(),
            name: self.name,
            host: self.host,
            port: self.port,
            username: self.username,
            password: self.password,
            term_type: self.term_type,
        }
    }
}

impl From<&SshProfile> for SshProfileConfig {
    fn from(profile: &SshProfile) -> Self {
        Self {
            name: profile.name.clone(),
            host: profile.host.clone(),
            port: profile.port,
            username: profile.username.clone(),
            password: profile.password.clone(),
            term_type: profile.term_type.clone(),
        }
    }
}

fn load_profiles_from_disk() -> Result<Vec<SshProfile>> {
    let path = Path::new(CONFIG_PATH);
    let content = match fs::read_to_string(path) {
        Ok(content) => content,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => return Err(error).with_context(|| format!("Failed to read {CONFIG_PATH}")),
    };
    let file: SshProfilesFile =
        serde_yaml::from_str(&content).with_context(|| format!("Failed to parse {CONFIG_PATH}"))?;
    Ok(file
        .profiles
        .into_iter()
        .map(SshProfileConfig::into_profile)
        .collect())
}

fn write_profiles_to_disk(profiles: &[SshProfile]) -> Result<()> {
    let path = Path::new(CONFIG_PATH);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("Failed to create {parent:?}"))?;
    }
    let file = SshProfilesFile {
        profiles: profiles.iter().map(SshProfileConfig::from).collect(),
    };
    let content = serde_yaml::to_string(&file).context("Failed to serialize SSH profiles")?;
    fs::write(path, content).with_context(|| format!("Failed to write {CONFIG_PATH}"))?;
    Ok(())
}

fn ensure_profiles_loaded(store: &mut ProfileStore) -> Result<()> {
    if store.initialized {
        return Ok(());
    }
    store.profiles = load_profiles_from_disk()?;
    store.initialized = true;
    Ok(())
}

pub fn list_profiles() -> Result<Vec<SshProfile>> {
    let mut store = PROFILE_STORE.lock().unwrap();
    ensure_profiles_loaded(&mut store)?;
    Ok(store.profiles.clone())
}

pub fn create_profile(
    name: String,
    host: String,
    port: u16,
    username: String,
    password: String,
    term_type: String,
) -> Result<SshProfile> {
    let mut store = PROFILE_STORE.lock().unwrap();
    ensure_profiles_loaded(&mut store)?;
    let profile = SshProfile {
        id: Uuid::new_v4().to_string(),
        name,
        host,
        port,
        username,
        password,
        term_type,
    };
    store.profiles.push(profile.clone());
    write_profiles_to_disk(&store.profiles)?;
    Ok(profile)
}

pub fn update_profile(
    id: String,
    name: String,
    host: String,
    port: u16,
    username: String,
    password: String,
    term_type: String,
) -> Result<SshProfile> {
    let mut store = PROFILE_STORE.lock().unwrap();
    ensure_profiles_loaded(&mut store)?;
    let index = store
        .profiles
        .iter()
        .position(|profile| profile.id == id)
        .ok_or_else(|| anyhow!("Profile not found"))?;
    let profile = SshProfile {
        id,
        name,
        host,
        port,
        username,
        password,
        term_type,
    };
    store.profiles[index] = profile.clone();
    write_profiles_to_disk(&store.profiles)?;
    Ok(profile)
}

pub fn delete_profile(id: String) -> Result<()> {
    let mut store = PROFILE_STORE.lock().unwrap();
    ensure_profiles_loaded(&mut store)?;
    let index = store
        .profiles
        .iter()
        .position(|profile| profile.id == id)
        .ok_or_else(|| anyhow!("Profile not found"))?;
    store.profiles.remove(index);
    write_profiles_to_disk(&store.profiles)?;
    Ok(())
}

#[cfg(test)]
fn clear_profiles_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
    let mut store = PROFILE_STORE.lock().unwrap();
    store.profiles.clear();
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
            self.path().join("config").join("ssh_profiles.yaml")
        }
    }

    impl Drop for TestWorkspace {
        fn drop(&mut self) {
            env::set_current_dir(&self.original_dir).unwrap();
        }
    }

    fn reset_store() {
        let mut store = PROFILE_STORE.lock().unwrap();
        store.profiles.clear();
        store.initialized = false;
    }

    #[test]
    fn missing_yaml_file_returns_empty_profiles() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();

        let profiles = list_profiles().unwrap();

        assert!(profiles.is_empty());
        assert!(!workspace.config_path().exists());
    }

    #[test]
    fn creates_profile_yaml_without_runtime_id() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();

        let created = create_profile(
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
            "xterm-truecolor".to_string(),
        )
        .unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(!created.id.is_empty());
        assert_eq!(created.term_type, "xterm-truecolor");
        assert!(yaml.contains("profiles:"));
        assert!(yaml.contains("name: Prod"));
        assert!(yaml.contains("host: example.com"));
        assert!(yaml.contains("port: 22"));
        assert!(yaml.contains("username: root"));
        assert!(yaml.contains("password: secret"));
        assert!(yaml.contains("term_type: xterm-truecolor"));
        assert!(!yaml.contains("id:"));
    }

    #[test]
    fn updates_profile_yaml_by_runtime_id() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        let created = create_profile(
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
            "xterm".to_string(),
        )
        .unwrap();

        let updated = update_profile(
            created.id.clone(),
            "Prod 2".to_string(),
            "example.org".to_string(),
            2222,
            "admin".to_string(),
            "new-secret".to_string(),
            "xterm-256color".to_string(),
        )
        .unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert_eq!(updated.id, created.id);
        assert_eq!(updated.term_type, "xterm-256color");
        assert!(yaml.contains("name: Prod 2"));
        assert!(yaml.contains("host: example.org"));
        assert!(yaml.contains("port: 2222"));
        assert!(yaml.contains("username: admin"));
        assert!(yaml.contains("password: new-secret"));
        assert!(yaml.contains("term_type: xterm-256color"));
        assert!(!yaml.contains("example.com"));
        assert!(!yaml.contains("term_type: xterm\n"));
        assert!(!yaml.contains("id:"));
    }

    #[test]
    fn deletes_profile_from_yaml_by_runtime_id() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        let first = create_profile(
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
            "xterm-256color".to_string(),
        )
        .unwrap();
        create_profile(
            "Stage".to_string(),
            "stage.example.com".to_string(),
            22,
            "deploy".to_string(),
            "stage-secret".to_string(),
            "xterm-color".to_string(),
        )
        .unwrap();

        delete_profile(first.id).unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(!yaml.contains("name: Prod"));
        assert!(yaml.contains("name: Stage"));
        assert!(yaml.contains("term_type: xterm-color"));
        assert!(!yaml.contains("id:"));
    }

    #[test]
    fn invalid_yaml_returns_error_and_preserves_file() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(workspace.config_path(), "profiles: [").unwrap();

        let result = list_profiles();

        assert!(result.is_err());
        assert_eq!(
            fs::read_to_string(workspace.config_path()).unwrap(),
            "profiles: ["
        );
    }

    #[test]
    fn reloads_yaml_in_order_with_new_runtime_ids() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(
            workspace.config_path(),
            r#"profiles:
- name: Prod
  host: example.com
  port: 22
  username: root
  password: secret
- name: Stage
  host: stage.example.com
  port: 2222
  username: deploy
  password: stage-secret
"#,
        )
        .unwrap();

        let first_load = list_profiles().unwrap();
        reset_store();
        let second_load = list_profiles().unwrap();

        assert_eq!(first_load.len(), 2);
        assert_eq!(second_load.len(), 2);
        assert_eq!(first_load[0].name, "Prod");
        assert_eq!(first_load[1].name, "Stage");
        assert_eq!(second_load[0].name, "Prod");
        assert_eq!(second_load[1].name, "Stage");
        assert_eq!(first_load[0].term_type, "xterm-256color");
        assert_eq!(first_load[1].term_type, "xterm-256color");
        assert_eq!(second_load[0].term_type, "xterm-256color");
        assert_eq!(second_load[1].term_type, "xterm-256color");
        assert_ne!(first_load[0].id, second_load[0].id);
        assert_ne!(first_load[1].id, second_load[1].id);
    }

    #[test]
    fn missing_term_type_defaults_to_xterm_256color() {
        let _guard = clear_profiles_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        fs::create_dir_all(workspace.path().join("config")).unwrap();
        fs::write(
            workspace.config_path(),
            r#"profiles:
- name: Legacy
  host: legacy.example.com
  port: 22
  username: root
  password: secret
"#,
        )
        .unwrap();

        let profiles = list_profiles().unwrap();

        assert_eq!(profiles.len(), 1);
        assert_eq!(profiles[0].term_type, "xterm-256color");
    }

    #[test]
    fn errors_when_profile_does_not_exist() {
        let _guard = clear_profiles_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();

        let update_result = update_profile(
            "missing".to_string(),
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
            "xterm-256color".to_string(),
        );
        let delete_result = delete_profile("missing".to_string());

        assert!(update_result.is_err());
        assert!(delete_result.is_err());
    }
}
