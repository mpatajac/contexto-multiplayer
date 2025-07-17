use serde::{Deserialize, Serialize};

use crate::game::{GameNumber, Guess, Score};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GuessScore {
    #[serde(rename(deserialize = "distance"))]
    pub score: Score,

    #[serde(rename(deserialize = "lemma"))]
    pub guess: Guess,
}

impl GuessScore {
    pub const fn is_correct(&self) -> bool {
        self.score == 1
    }
}

#[derive(Debug, Deserialize)]
struct GuessError {
    error: String,
}

pub async fn get_guess_score(
    client: &reqwest::Client,
    game_number: GameNumber,
    guess: Guess,
) -> Result<GuessScore, String> {
    let mut headers = reqwest::header::HeaderMap::new();
    headers.insert(
        "Accept-Encoding",
        "gzip, deflate, br, zstd"
            .parse()
            .expect("should be able to parse header"),
    );

    let request = client
        .request(
            reqwest::Method::GET,
            format!("https://api.contexto.me/machado/en/game/{game_number}/{guess}"),
        )
        .headers(headers);

    let response = request.send().await.map_err(|err| {
        tracing::error!({error = %err});

        err.to_string()
    })?;

    if response.status().is_success() {
        Ok(response
            .json::<GuessScore>()
            .await
            .map(|mut guess_score| {
                // score is 1 greater then the distance (which we receive)
                guess_score.score += 1;
                guess_score
            })
            .map_err(|err| err.to_string())?)
    } else {
        Err(response
            .json::<GuessError>()
            .await
            .map_err(|err| err.to_string())?
            .error)
    }
}
