use std::{collections::HashMap, convert::Infallible, net::SocketAddr, sync::Arc, time::Duration};

use axum::extract::{ConnectInfo, Path, State};
use tokio_stream::Stream;

use crate::{
    config::CONFIG,
    data::{AppState, SessionId},
    game::{GameNumber, GameState, Guess, GuessScore},
};

use super::message::Message;

// region: Sse connections tracking

/// Shorthand for the transmit half of the message channel.
type Tx = tokio::sync::mpsc::UnboundedSender<Message>;

/// `Clients` is a collection of subscribed clients (`SocketAddr`)
/// and channel transmit parts (`Tx`) used to send them messages.
type Clients = HashMap<SocketAddr, Tx>;

#[derive(Debug)]
struct Session {
    clients: Clients,
    game_state: GameState,
}

/// Collection of all SSE connections, grouped by session (id).
#[derive(Debug)]
pub struct Connections {
    sessions: HashMap<SessionId, Session>,
}

impl Connections {
    /// Create a new, empty, instance of `Connections`.
    pub fn new() -> Self {
        Self {
            sessions: HashMap::new(),
        }
    }

    pub fn game_number(&self, session_id: &SessionId) -> Option<GameNumber> {
        self.sessions
            .get(session_id)
            .map(|session| &session.game_state.game_number)
            .copied()
    }

    pub fn add_guess(&mut self, session_id: &SessionId, guess_score: GuessScore) {
        if let Some(session) = self.sessions.get_mut(session_id) {
            session
                .game_state
                .guesses
                .insert(guess_score.guess, guess_score.score);
        } else {
            tracing::info!(
                { session_id = session_id },
                "Adding guess for non-existant session."
            );
        }
    }

    pub fn word_guessed(&mut self, session_id: &SessionId, word: Guess) {
        if let Some(session) = self.sessions.get_mut(session_id) {
            session.game_state.target_word = Some(word);
        } else {
            tracing::info!(
                { session_id = session_id },
                "Adding guess for non-existant session."
            );
        }
    }

    pub fn join_game(&mut self, session_id: &SessionId, game_number: GameNumber) -> GameState {
        tracing::debug!("Player joining session {session_id}");

        if !self.sessions.contains_key(session_id) {
            self.sessions.insert(
                session_id.clone(),
                Session {
                    clients: HashMap::new(),
                    game_state: GameState::new(game_number),
                },
            );
        }

        self.sessions
            .get(session_id)
            .expect("should be present")
            .game_state
            .clone()
    }

    /// Send a message to all clients in a session
    pub fn broadcast(&self, session_id: &SessionId, message: &Message) {
        if let Some(session) = self.sessions.get(session_id) {
            tracing::debug!("Sending message `{message}` to session {session_id}");

            for client in session.clients.values() {
                if let Err(error) = client.send(message.clone()) {
                    tracing::error!("Failed to send a message: {error:#?}");
                    // TODO: add retry mechanism?
                    // NOTE: be careful not to get stuck trying to recover
                    // (as we are in a locked mutex)
                }
            }
        }
    }

    /// Send a `Shutdown` message to every client
    pub fn shutdown(&self) {
        let shutdown_message = Message::Shutdown;

        for session in self.sessions.values() {
            for client in session.clients.values() {
                if let Err(error) = client.send(shutdown_message.clone()) {
                    tracing::error!("Failed to send shutdown message: {error:#?}");
                }
            }
        }
    }

    fn add_client(
        &mut self,
        session_id: SessionId,
        game_number: GameNumber,
        addr: SocketAddr,
        tx: Tx,
    ) {
        tracing::debug!("Adding client `{addr}` to session {session_id}");

        self.sessions
            // check if there are any stored connections related to given session (id)
            .entry(session_id)
            // if yes, add this new connection to existing collection
            .and_modify(|session| {
                session.clients.insert(addr, tx.clone());
            })
            // otherwise add new tracker for the session, containing this connection
            .or_insert_with(|| Session {
                clients: HashMap::from([(addr, tx)]),
                game_state: GameState::new(game_number),
            });
    }

    fn remove_client(&mut self, session_id: &SessionId, addr: SocketAddr) {
        tracing::debug!("Removing client `{addr}` from session {session_id}");

        // make sure the session has (some) existing connections
        if let Some(session) = self.sessions.get_mut(session_id) {
            // remove the client from session collection
            session.clients.remove(&addr);

            // TODO: don't remove here, as we would lose all game state
            // - have job remove them
            // if the session is empty, remove it too
            // if session.clients.is_empty() {
            //     self.sessions.remove(session_id);
            // }
        }
    }
}

// endregion

/// Establish a new SSE client subscription.
pub(super) async fn subscribe(
    State(app_state): State<Arc<AppState>>,
    Path(session_id): Path<SessionId>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
) -> axum::response::Sse<impl Stream<Item = Result<axum::response::sse::Event, Infallible>>> {
    tracing::debug!("Subscribing `{addr:?}` to messages from session {session_id}");

    // create communication channel
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    // NOTE: keep this in a block to try and release the `Mutex` lock ASAP
    // (don't know if this actually makes any difference)
    {
        // add client to pool
        app_state.sse.lock().await.add_client(
            session_id.clone(),
            AppState::game_number(),
            addr,
            tx.clone(),
        );
    }

    handle_client_disconnect(app_state, session_id, addr, tx);

    let stream = async_stream::try_stream! {
        // handle messages
        while let Some(message) = rx.recv().await {
            if matches!(message, Message::Shutdown) {
                tracing::warn!("Shutting down - waiting for remaining messages...");

                // receive any remaining messages and close connection
                rx.close();
            } else {
                // we don't want to send internal messages
                yield message.into();
            }
        }
    };

    let keep_alive = axum::response::sse::KeepAlive::new()
        .interval(Duration::from_secs(CONFIG.sse_keep_alive_interval));

    axum::response::Sse::new(stream).keep_alive(keep_alive)
}

/// Handles client disconnecting by removing them from the client pool.
fn handle_client_disconnect(
    app_state: Arc<AppState>,
    session_id: SessionId,
    addr: SocketAddr,
    tx: Tx,
) {
    tokio::spawn(async move {
        tx.closed().await;

        app_state.sse.lock().await.remove_client(&session_id, addr);
    });
}
