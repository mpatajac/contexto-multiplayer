use std::{path::Path, sync::Arc};

use axum::Router;
use tower_http::services::ServeDir;

use crate::{api, data::AppState, sse};

pub fn router(app_state: Arc<AppState>, dist_root: &Path) -> Router {
    Router::new()
        .nest("/api", api::router(app_state.clone()))
        .nest("/sse", sse::router(app_state))
        .fallback_service(static_router(dist_root))
}

fn static_router(dist_root: &Path) -> Router {
    Router::new()
        .nest_service("/:room_number", ServeDir::new(dist_root.join("app")))
        .fallback_service(ServeDir::new(dist_root.join("app")))
}
