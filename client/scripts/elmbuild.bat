set dest="../dist/app"

cd ../

robocopy ./ %dest% index.html
robocopy ./style/ %dest%/style/ *.css

elm make --debug src/Main.elm --output=elm-app.js

move elm-app.js %dest%/elm-app-min.js

cd ./scripts
