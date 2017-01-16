open Batteries
open BatFormat
open BatOptParse

open Lexing
open AST
open Exp       
open Tycheck
open Ssa

let print_pos lexbuf =
  let pos = lexbuf.lex_curr_p in
  pos.pos_fname ^ " line " ^ (string_of_int pos.pos_lnum) ^
    " col " ^ (string_of_int (pos.pos_cnum - pos.pos_bol + 1))

let string_of_id = function Id s -> s

let string_of_value = function
  | VInt i -> Int32.to_string i
  | VFloat f -> string_of_float f
  | VUnit -> "unit"
  | VBool b -> string_of_bool b
  | VLoc id -> string_of_id id

(** The interpret function called from JavaScript *)
let js_interpret s =
  (* redirect interpreter output to a string *)
  let outs = BatIO.output_string () in
  set_formatter_output outs;

  let body = Js.to_string s in
  if String.trim body = "" then
    Js.string ("Error: empty program")
  else
    let lexbuf = Lexing.from_string body in
    try
      let p = Parser.prog Lexer.token lexbuf in
      let p_tychecked = tycheck_prog p in
      let p_rtl = ssa_of_prog p_tychecked in
      let v = ssa_interp p_rtl in

      (* get output string *)
      let output = BatIO.close_out outs in

      (* return output string and result value *)
      Js.string (output ^ "\n Result: " ^ (string_of_value v))
    with
    | Parser.Error ->
       Js.string ("Syntax error: " ^ (print_pos lexbuf))
    | Lexer.Syntax_err msg ->
       Js.string ("Lexer error: " ^ (print_pos lexbuf) ^ "\n" ^  msg)
    | Ty_error msg ->
       Js.string ("Type error: " ^ msg)
    | Codegen_error err ->
       Js.string ("Codegen error: " ^ err)
    | Ssa_interp_error err ->
       Js.string ("Interpreter error: " ^ err)

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
                      (Js.wrap_callback js_interpret)
