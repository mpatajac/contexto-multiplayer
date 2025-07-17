use serde::{Deserialize, Serialize};

use crate::game::{Guess, GuessScore};

#[derive(Debug, Clone, Serialize, Deserialize, strum_macros::Display)]
#[serde(rename_all = "camelCase")]
#[serde(untagged)]
#[strum(serialize_all = "camelCase")]
pub enum Message {
    NewGuess {
        #[serde(flatten)]
        guess_score: GuessScore,
    },

    CorrectGuess {
        word: Guess,
    },

    // Internal
    // prevent `Shutdown` (de)serialization (to prevent actually sending it)
    #[serde(skip)]
    Shutdown,
}

impl From<Message> for axum::response::sse::Event {
    fn from(message: Message) -> Self {
        Self::default()
            // use message's `kind` as (sse) event type
            .event(message.to_string())
            .json_data(message.clone())
            .map_err(|error| {
                tracing::error!(
                    "Failed to convert a Message to a sse event.\nMessage: {message:#?}\nError: {error}",
                );
            })
            .expect("should contain valid data and form")
    }
}
