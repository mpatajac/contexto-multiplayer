#!/usr/bin/env bash

ROOT=".."
DEST="../dist/app"

cd ../

mkdir -p "$DEST"
mkdir -p "$DEST/style"

cp ./index.html "$DEST/index.html"
cp -r ./style/*.css "$DEST/style/"

"$ROOT/elm" make src/Main.elm --optimize --output=elm-app.js

mv ./elm-app.js "$DEST/elm-app-min.js"

cd ./scripts
