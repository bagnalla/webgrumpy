# webgrumpy
CS4100 grumpy compiler web interface

Install js_of_ocaml through opam, put the file grumpyjs.ml in the grumpy src
directory, then use the following commands to build grumpyjs.js:

ocamlbuild -use-ocamlfind -pkgs "js_of_ocaml,js_of_ocaml.syntax" -use-menhir -syntax camlp4o grumpyjs.byte

js_of_ocaml +nat.js +weak.js grumpyjs.byte

