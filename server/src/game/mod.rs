pub mod game_state;
pub mod guess;

pub use game_state::GameState;
pub use guess::GuessScore;

pub type Guess = String;
pub type Score = usize;
pub type GameNumber = u32;
