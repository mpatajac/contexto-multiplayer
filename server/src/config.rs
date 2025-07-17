use std::sync::LazyLock;

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    pub dist_root_path: String,
    pub sse_keep_alive_interval: u64,
}

// region: loading & constant

fn load(path: &str) -> ServerConfig {
    let file =
        std::fs::read_to_string(path).expect("config file should be present in project structure");

    toml::from_str(file.as_str()).expect("config should have valid format (TOML)")
}

pub static CONFIG: LazyLock<ServerConfig> = LazyLock::new(|| load("./Config.toml"));

// endregion
