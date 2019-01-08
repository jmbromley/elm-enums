#!/usr/bin/env node

var fs = require('fs');
var Elm = require('./build/elm-enums.js');

var app = Elm.Elm.Main.init();
app.ports.output.subscribe(writeOutput);

try { 
    var contents = fs.readFileSync('enums.defs', 'utf8');
    app.ports.input.send(contents);
} catch(error) { 
    switch(error.code) {
    case "ENOENT":
        console.error("Error: Could not find input file ./enums.defs");
        process.exit(1);
        break;
    case "EACCES":
        console.error("Permission denied: unable to open file ./enums.defs for reading");
        process.exit(1);
        break;
    case "EISDIR":
        console.error("Error: ./enums.defs is not a regular file");
        process.exit(1);
        break;
    default:
        console.error("Uncaught Error: " + error.code + ". Please file a bug report!");
        process.exit(1);
    }
}

function writeOutput(data) {
    if (data.error) {
        console.log("Syntax error in ./enums.defs: " + data.error);
        process.exit(3);
    } else {
        if (fs.existsSync('Enums.elm')) {
            fs.renameSync('Enums.elm', 'Enums.elm.bak');
            console.log("Info: Old version of ./Enums.elm moved to ./Enums.elm.bak");        
        }
        fs.writeFileSync('Enums.elm', data.result, 'utf8');
        console.log("Success: types and decoders written to ./Enums.elm");
        process.exit(0);
    }
}
