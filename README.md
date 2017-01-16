# webgrumpy
CS4100 grumpy compiler web interface

Install js_of_ocaml through opam then add this target to the makefile

js:
	ocamlbuild -use-ocamlfind -pkgs "js_of_ocaml,js_of_ocaml.syntax" \
	-use-menhir -syntax camlp4o grumpyjs.byte
	js_of_ocaml +nat.js +weak.js grumpyjs.byte

and build the file grumpyjs.js with "make js". Then put grumpy.js in the
scripts directory.
