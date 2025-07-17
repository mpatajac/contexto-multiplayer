use std::sync::Arc;

use axum::{
    Json,
    extract::{Path, State},
};

use crate::{
    data::{AppState, SessionId},
    error::ErrorResponse,
    game::{self, Guess, GuessScore},
    sse,
};

pub async fn handle(
    State(app_state): State<Arc<AppState>>,
    Path(session_id): Path<SessionId>,
    Json(guess): Json<Guess>,
) -> Result<Json<GuessScore>, ErrorResponse> {
    tracing::debug!("Guess in session {session_id}: `{guess}`");

    let Some(game_number) = ({ app_state.sse.lock().await.game_number(&session_id) }) else {
        tracing::error!("Cannot get game number in session {session_id}");
        return Err(ErrorResponse::internal_server_error());
    };

    match game::guess::get_guess_score(&app_state.http_client, game_number, guess).await {
        Err(error) => {
            tracing::debug!({error = %error});
            Err(ErrorResponse::not_found(error))
        }
        Ok(guess_score) => {
            if guess_score.is_correct() {
                handle_correct_guess(app_state, session_id, guess_score).await
            } else {
                handle_guess_score(app_state, session_id, guess_score).await
            }
        }
    }
}

async fn handle_correct_guess(
    app_state: Arc<AppState>,
    session_id: SessionId,
    guess_score: GuessScore,
) -> Result<Json<GuessScore>, ErrorResponse> {
    let word = guess_score.guess.clone();

    {
        let mut connections = app_state.sse.lock().await;

        connections.word_guessed(&session_id, word.clone());
        connections.broadcast(&session_id, &sse::Message::CorrectGuess { word });
    };

    Ok(Json(guess_score))
}

async fn handle_guess_score(
    app_state: Arc<AppState>,
    session_id: SessionId,
    guess_score: GuessScore,
) -> Result<Json<GuessScore>, ErrorResponse> {
    {
        let mut connections = app_state.sse.lock().await;

        connections.add_guess(&session_id, guess_score.clone());
        connections.broadcast(
            &session_id,
            &sse::Message::NewGuess {
                guess_score: guess_score.clone(),
            },
        );
    };

    Ok(Json(guess_score))
}
