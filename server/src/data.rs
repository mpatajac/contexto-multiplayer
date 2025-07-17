// region: AppState

use std::sync::Arc;

use crate::{game::GameNumber, sse};

#[derive(Debug)]
pub struct AppState {
    pub http_client: reqwest::Client,
    // TODO?: check the read/write ratio, see if using `RwLock` would be more appropriate
    pub sse: tokio::sync::Mutex<sse::Connections>,
}

impl AppState {
    pub fn init() -> anyhow::Result<Arc<Self>> {
        tracing::debug!("App state init...");

        let sse = tokio::sync::Mutex::new(sse::Connections::new());
        let http_client = reqwest::Client::builder().build()?;

        let app_state = Self { http_client, sse };

        Ok(Arc::new(app_state))
    }

    pub fn game_number() -> GameNumber {
        const START_DATE: chrono::NaiveDate =
            chrono::NaiveDate::from_ymd_opt(2022, 9, 18).expect("should be a valid date");

        let now = chrono::Utc::now().naive_utc().date();
        (now - START_DATE)
            .num_days()
            .try_into()
            .expect("should be within range")
    }
}

// endregion

// region: SessionId

pub type SessionId = String;

// endregion
