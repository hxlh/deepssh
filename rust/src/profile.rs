use std::sync::Mutex;

use anyhow::{anyhow, Result};
use once_cell::sync::Lazy;
use uuid::Uuid;

static PROFILE_STORE: Lazy<Mutex<Vec<SshProfile>>> = Lazy::new(|| Mutex::new(Vec::new()));

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SshProfile {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub password: String,
}

pub fn list_profiles() -> Vec<SshProfile> {
    PROFILE_STORE.lock().unwrap().clone()
}

pub fn create_profile(
    name: String,
    host: String,
    port: u16,
    username: String,
    password: String,
) -> SshProfile {
    let profile = SshProfile {
        id: Uuid::new_v4().to_string(),
        name,
        host,
        port,
        username,
        password,
    };
    PROFILE_STORE.lock().unwrap().push(profile.clone());
    profile
}

pub fn update_profile(
    id: String,
    name: String,
    host: String,
    port: u16,
    username: String,
    password: String,
) -> Result<SshProfile> {
    let mut profiles = PROFILE_STORE.lock().unwrap();
    let index = profiles
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
    };
    profiles[index] = profile.clone();
    Ok(profile)
}

pub fn delete_profile(id: String) -> Result<()> {
    let mut profiles = PROFILE_STORE.lock().unwrap();
    let index = profiles
        .iter()
        .position(|profile| profile.id == id)
        .ok_or_else(|| anyhow!("Profile not found"))?;
    profiles.remove(index);
    Ok(())
}

#[cfg(test)]
fn clear_profiles_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = TEST_LOCK.lock().unwrap();
    PROFILE_STORE.lock().unwrap().clear();
    guard
}

#[cfg(test)]
static TEST_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_updates_and_deletes_profiles() {
        let _guard = clear_profiles_for_test();

        let created = create_profile(
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
        );

        assert_eq!(created.name, "Prod");
        assert_eq!(list_profiles(), vec![created.clone()]);

        let updated = update_profile(
            created.id.clone(),
            "Prod 2".to_string(),
            "example.org".to_string(),
            2222,
            "admin".to_string(),
            "new-secret".to_string(),
        )
        .unwrap();

        assert_eq!(updated.name, "Prod 2");
        assert_eq!(updated.port, 2222);

        delete_profile(created.id).unwrap();
        assert!(list_profiles().is_empty());
    }

    #[test]
    fn errors_when_profile_does_not_exist() {
        let _guard = clear_profiles_for_test();

        let update_result = update_profile(
            "missing".to_string(),
            "Prod".to_string(),
            "example.com".to_string(),
            22,
            "root".to_string(),
            "secret".to_string(),
        );
        let delete_result = delete_profile("missing".to_string());

        assert!(update_result.is_err());
        assert!(delete_result.is_err());
    }
}
