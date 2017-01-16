var $ = require('jquery-browserify')

function setResults(res) {
    let results = ace.edit("results");
    results.setValue(res);
    results.session.selection.clearSelection();
}

function createWorker() {
    var worker = new Worker ("./scripts/grumpyjs.js");
    worker.onmessage = function (m) {
	if (typeof m.data == 'string') {
            console.log("" + m.data);
	} else {
            console.log ("[ASYNCH] back from " + m.data.fname);
            var handler = worker_handler[m.data.fname];
            handler (m.data.result);
	}
    }
    worker.onerror = function(event){
	setResults("Grumpy exception: " + event.message);
    };
    return worker;
}

var worker_handler = new Object ();
var worker = createWorker();

// taken from http://toss.sourceforge.net/ocaml.html
function ASYNCH (action_name, action_args, cont) {
    worker_handler[action_name] = cont;
    worker.postMessage ({fname: action_name, args: action_args});
    console.log ("[ASYNCH] " + action_name + " (" + action_args + ")");
}

function cancelWorker () {
    worker.terminate();
    worker = undefined;
    worker = createWorker();
}

var timeoutId = null;
function startTimeout() {
    timeoutId = setTimeout(function() {
	cancelWorker();
	let results = ace.edit("results");
	setResults("Timed out after 30 seconds.");
    }, 30000);
}

function cancelTimeout() {
    if (timeoutId !== null) {
	clearTimeout(timeoutId);
	timeoutId = null;
    }
}

function interpret () {
    startTimeout();
    $("#gobutton").prop('disabled', true);

    setResults("Interpreting...");

    let editor = ace.edit("editor");
    var txt = editor.getValue();

    ASYNCH ("interpret", [txt], function (response) {
	cancelTimeout();
	$("#gobutton").prop('disabled', false);
	setResults(response);
    })
}

$("#gobutton").click(function() {
    interpret();
});

let editor = ace.edit("editor");
editor.setTheme("ace/theme/iplastic");
editor.session.setMode("ace/mode/javascript");
editor.session.setUseWorker(false);

let results = ace.edit("results");
results.setTheme("ace/theme/iplastic");
// results.session.setMode("ace/mode/javascript");
results.session.setUseWorker(false);
results.setReadOnly(true);
