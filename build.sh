#!/bin/bash

#Requires Elm 0.19 and UglifyJS to build.

elm make --output=build/tmp.js --optimize src/Main.elm
uglifyjs build/tmp.js --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=build/elm-enums.js
rm build/tmp.js
