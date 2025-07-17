set dest="../dist/app"

cd ../

robocopy ./ %dest% index.html
robocopy ./style/ %dest%/style/ *.css

elm make src/Main.elm --optimize --output=elm-app.js
uglifyjs elm-app.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output elm-app-min.js

move elm-app-min.js %dest%/elm-app-min.js

del elm-app.js
cd ./scripts
