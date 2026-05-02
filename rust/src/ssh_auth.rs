use std::{path::Path, sync::Arc};

use russh::{
    client,
    keys::{key::PrivateKeyWithHashAlg, load_secret_key, ssh_key::PrivateKey, Error as KeyError},
};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SshConnectErrorCode {
    PassphraseRequired,
    PrivateKeyFileUnreadable,
    InvalidPrivateKey,
    AuthenticationFailed,
    ConnectionFailed,
    ChannelFailed,
    PtyFailed,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SshConnectError {
    pub code: SshConnectErrorCode,
    pub message: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SshAuthCredential {
    pub password: Option<String>,
    pub private_key_path: Option<String>,
    pub passphrase: Option<String>,
}

#[flutter_rust_bridge::frb(ignore)]
pub fn connect_error(code: SshConnectErrorCode, message: impl Into<String>) -> SshConnectError {
    SshConnectError {
        code,
        message: message.into(),
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub fn load_private_key(
    path: &Path,
    passphrase: Option<&str>,
) -> Result<PrivateKey, SshConnectError> {
    load_secret_key(path, passphrase).map_err(|error| match error {
        KeyError::IO(_) => connect_error(
            SshConnectErrorCode::PrivateKeyFileUnreadable,
            format!("Failed to read private key file: {}", path.display()),
        ),
        KeyError::KeyIsEncrypted => connect_error(
            SshConnectErrorCode::PassphraseRequired,
            "Private key requires a passphrase",
        ),
        error => connect_error(
            SshConnectErrorCode::InvalidPrivateKey,
            format!("Invalid private key: {error}"),
        ),
    })
}

#[flutter_rust_bridge::frb(ignore)]
pub async fn authenticate<H: client::Handler>(
    handle: &mut client::Handle<H>,
    username: String,
    credential: SshAuthCredential,
) -> Result<(), SshConnectError> {
    let auth = if let Some(private_key_path) = credential.private_key_path {
        let key = load_private_key(
            Path::new(&private_key_path),
            credential.passphrase.as_deref(),
        )?;
        handle
            .authenticate_publickey(username, PrivateKeyWithHashAlg::new(Arc::new(key), None))
            .await
            .map_err(|error| {
                connect_error(
                    SshConnectErrorCode::AuthenticationFailed,
                    format!("SSH private key auth failed: {error:?}"),
                )
            })?
    } else {
        handle
            .authenticate_password(username, credential.password.unwrap_or_default())
            .await
            .map_err(|error| {
                connect_error(
                    SshConnectErrorCode::AuthenticationFailed,
                    format!("SSH password auth failed: {error:?}"),
                )
            })?
    };

    if auth.success() {
        Ok(())
    } else {
        Err(connect_error(
            SshConnectErrorCode::AuthenticationFailed,
            "SSH authentication failed",
        ))
    }
}

#[cfg(test)]
mod tests {
    use std::fs;

    use super::*;

    const ENCRYPTED_ED25519_KEY: &str = r#"-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABD1phlku5
A2G7Q9iP+DcOc9AAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIHeLC1lWiCYrXsf/
85O/pkbUFZ6OGIt49PX3nw8iRoXEAAAAkKRF0st5ZI7xxo9g6A4m4l6NarkQre3mycqNXQ
dP3jryYgvsCIBAA5jMWSjrmnOTXhidqcOy4xYCrAttzSnZ/cUadfBenL+DQq6neffw7j8r
0tbCxVGp6yCQlKrgSZf6c0Hy7dNEIU2bJFGxLe6/kWChcUAt/5Ll5rI7DVQPJdLgehLzvv
sJWR7W+cGvJ/vLsw==
-----END OPENSSH PRIVATE KEY-----"#;

    #[test]
    fn encrypted_private_key_without_passphrase_returns_prompt_error() {
        let temp_dir = tempfile::tempdir().unwrap();
        let key_path = temp_dir.path().join("id_ed25519");
        fs::write(&key_path, ENCRYPTED_ED25519_KEY).unwrap();

        let error = load_private_key(&key_path, None).unwrap_err();

        assert_eq!(error.code, SshConnectErrorCode::PassphraseRequired);
    }

    #[test]
    fn encrypted_private_key_with_passphrase_loads_key() {
        let temp_dir = tempfile::tempdir().unwrap();
        let key_path = temp_dir.path().join("id_ed25519");
        fs::write(&key_path, ENCRYPTED_ED25519_KEY).unwrap();

        let key = load_private_key(&key_path, Some("test")).unwrap();

        assert!(key.algorithm().is_ed25519());
    }

    #[test]
    fn missing_private_key_returns_unreadable_error() {
        let temp_dir = tempfile::tempdir().unwrap();
        let key_path = temp_dir.path().join("missing");

        let error = load_private_key(&key_path, None).unwrap_err();

        assert_eq!(error.code, SshConnectErrorCode::PrivateKeyFileUnreadable);
    }

    #[test]
    fn invalid_private_key_returns_invalid_key_error() {
        let temp_dir = tempfile::tempdir().unwrap();
        let key_path = temp_dir.path().join("id_ed25519");
        fs::write(&key_path, "not a private key").unwrap();

        let error = load_private_key(&key_path, None).unwrap_err();

        assert_eq!(error.code, SshConnectErrorCode::InvalidPrivateKey);
    }
}
