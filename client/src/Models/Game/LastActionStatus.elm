module Models.Game.LastActionStatus exposing (LastActionStatus(..))

import Models.GuessScore exposing (GuessScore)
import Utils.Data.Error exposing (ErrorMessage)


type LastActionStatus
    = Initial
    | Processing
    | Guess GuessScore
    | Message ErrorMessage
