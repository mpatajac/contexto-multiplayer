pub mod message;
mod message_dispatch;

use std::sync::Arc;

use axum::{Router, routing::get};

use crate::data::AppState;

pub use message::Message;
pub use message_dispatch::Connections;

pub fn router(app_state: Arc<AppState>) -> Router {
    Router::new()
        .route("/:session_id", get(message_dispatch::subscribe))
        .with_state(app_state)
}
