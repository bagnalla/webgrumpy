open BatFormat
open Lexing
open AST
open Tycheck
open Ssa
open Grumpyjsutil

let print_pos lexbuf =
  let pos = lexbuf.lex_curr_p in
  pos.pos_fname ^ " line " ^ (string_of_int pos.pos_lnum) ^
    " col " ^ (string_of_int (pos.pos_cnum - pos.pos_bol + 1))

(** The interpret function called from JavaScript *)
let js_interpret s =
  (* redirect interpreter output to a string *)
  let outs = BatIO.output_string () in
  set_formatter_output outs;

  (* clear tokens *)
  clear_tokens ();

  let body = Js.to_string s in
  if String.trim body = "" then
    WRError "Error: empty program"
  else
    let lexbuf = Lexing.from_string body in
    try
      let p = Parser.prog Lexer.token lexbuf in
      let p_tychecked = tycheck_prog p in
      let p_rtl = ssa_of_prog p_tychecked in
      let v = ssa_interp p_rtl in

      (* get output string *)
      let output = BatIO.close_out outs in
      (* escape newlines for the sake of JSON *)
      (* let output' = Str.global_replace (Str.regexp "\n") "\\n" output in *)
      (* let output' = String.escaped output in *)

      (* return output string and result value *)
      (* Js.string (output ^ "\n Result: " ^ (string_of_value v)) *)
      WRSuccess (output ^ "\n Result: " ^ (string_of_value v) ^ "\n", v, BatList.rev (get_tokens ()), VTStub, TDStub, "\n",
                 "\n");
    with
    | Parser.Error ->
       WRError ("Syntax error: " ^ (print_pos lexbuf) ^ "\n")
    | Lexer.Syntax_err msg ->
       WRError ("Lexer error: " ^ (print_pos lexbuf) ^ "\n" ^  msg ^ "\n")
    | Ty_error msg ->
       WRError ("Type error: " ^ msg ^ "\n")
    | Codegen_error err ->
       WRError ("Codegen error: " ^ err ^ "\n")
    | Ssa_interp_error err ->
       WRError ("Interpreter error: " ^ err ^ "\n")

(** Web worker boilerplate *)
(** Taken from http://toss.sourceforge.net/ocaml.html *)
let js_object = Js.Unsafe.variable "Object"
let js_handler = jsnew js_object ()
let postMessage = Js.Unsafe.variable "postMessage"
let log s = ignore (Js.Unsafe.call postMessage (Js.Unsafe.variable "self")
		                   [|Js.Unsafe.inject (Js.string s)|])
let onmessage event =
  let fname = event##data##fname in
  let args = event##data##args in
  let handle = Js.Unsafe.get js_handler fname in
  let result = Js.Unsafe.fun_call handle (Js.to_array args) in
  let response = jsnew js_object () in
  Js.Unsafe.set response (Js.string "fname") fname;
  Js.Unsafe.set response (Js.string "result") result;
  Js.Unsafe.call postMessage (Js.Unsafe.variable "self")
                 [|Js.Unsafe.inject response|]
let _ = Js.Unsafe.set (Js.Unsafe.variable "self")
                      (Js.string "onmessage") onmessage

(** Set this to match the OCaml function *)
let _ = Js.Unsafe.set js_handler (Js.string "interpret")
                      (Js.wrap_callback
                         (fun s ->
                           (Js.string
                              (json_string_of_webresponse (js_interpret s)))))
