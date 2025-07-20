mod guess;
mod join_session;

use std::sync::Arc;

use axum::{
    Router,
    routing::{get, post},
};

use crate::data::AppState;

pub fn router(app_state: Arc<AppState>) -> Router {
    Router::new().nest("/:session_id", session_router(app_state))
}

fn session_router(app_state: Arc<AppState>) -> Router {
    Router::new()
        .route("/", get(join_session::handle))
        .route("/guess", post(guess::handle))
        .with_state(app_state)
}
