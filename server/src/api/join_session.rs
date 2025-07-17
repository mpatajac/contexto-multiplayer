use std::sync::Arc;

use axum::{
    Json,
    extract::{Path, State},
};

use crate::{
    data::{AppState, SessionId},
    error::ErrorResponse,
    game::GameState,
};

pub async fn handle(
    State(app_state): State<Arc<AppState>>,
    Path(session_id): Path<SessionId>,
) -> Result<Json<GameState>, ErrorResponse> {
    tracing::debug!("Joining game in session {session_id}");

    let game_state = {
        app_state
            .sse
            .lock()
            .await
            .join_game(&session_id, AppState::game_number())
    };

    Ok(Json(game_state))
}
