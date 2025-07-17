use std::collections::HashMap;

use serde::Serialize;

use crate::game::{GameNumber, Guess, Score};

#[derive(Debug, Clone, Serialize)]
pub struct GameState {
    pub target_word: Option<Guess>,
    pub game_number: GameNumber,
    pub guesses: HashMap<Guess, Score>,
}

impl GameState {
    pub fn new(game_number: GameNumber) -> Self {
        Self {
            target_word: None,
            game_number,
            guesses: HashMap::new(),
        }
    }
}
