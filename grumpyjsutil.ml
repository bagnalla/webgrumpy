open Lexing
open AST
open Simplejson
open Exp
open AST

let rec intersperse lst sep =
  match lst with
  | x :: y :: t -> x :: sep :: intersperse (y :: t) sep
  | _ -> lst

let string_of_id = function Id s -> s

let rec string_of_ty = function
  | TyInt -> "TyInt"
  | TyFloat -> "TyFloat"
  | TyBool -> "TyBool"
  | TyRef t -> "TyRef " ^ string_of_ty t
  | TyUnit -> "TyUnit"

let string_of_tid ti =
  string_of_id ti.id_of ^ " : " ^ string_of_ty ti.ty_of

let string_of_unop = function
  | UMinus -> "UMinus"
  | UNot -> "UNot"
  | UDeref -> "UDeref"

let string_of_binop = function
  | BPlus -> "BPlus"
  | BMinus -> "BMinus"
  | BTimes -> "BTimes"
  | BDiv -> "BDiv"
  | BAnd -> "BAnd"
  | BOr -> "BOr"
  | BLt -> "BLt"
  | BIntEq -> "BIntEq"
  | BUpdate -> "BUpdate"

let string_of_value = function
  | VInt i -> Int32.to_string i
  | VFloat f -> string_of_float f
  | VUnit -> "unit"
  | VBool b -> string_of_bool b
  | VLoc id -> string_of_id id

(**********)
(* Tokens *)
(**********)

type token = (string * Lexing.position * Lexing.position)
let tokens : token list ref = ref []

let add_token tok lexbuf =
  tokens := (tok, lexeme_start_p lexbuf, lexeme_end_p lexbuf) :: !tokens

let get_tokens () = !tokens

let clear_tokens () = tokens := []

(* Not exacly a direct mapping of the token object *)
let json_of_token token =
  let (tok, start, end') = token in
  JSAssoc ["token", JSString tok;
           "start_lnum", JSString (string_of_int start.pos_lnum);
           "start_cnum", JSString (string_of_int (start.pos_cnum -
                                                    start.pos_bol));
           "end_lnum", JSString (string_of_int end'.pos_lnum);
           "end_cnum", JSString (string_of_int (end'.pos_cnum -
                                                  end'.pos_bol))]

(*******)
(* AST *)
(*******)

(* start and end line and column numbers *)
type vistree_info = int*int*int*int

(* Very much like an s-expression, but will probably carry some extra
   information *)
type vistree =
  | VTAtom of string
  | VTList of vistree_info * vistree list

let json_of_vistree_info (start_lnum, start_cnum, end_lnum, end_cnum) =
  JSAssoc ["start_lnum", JSString (string_of_int start_lnum);
           "start_cnum", JSString (string_of_int start_cnum);
           "end_lnum", JSString (string_of_int end_lnum);
           "end_cnum", JSString (string_of_int end_cnum)]

let rec json_of_vistree = function
  | VTAtom a -> JSString a
  | VTList (info, lst) ->
     JSList (json_of_vistree_info info :: BatList.map json_of_vistree lst)

let vistree_info_of_exp e =
  e.start_of.pos_lnum,
  e.start_of.pos_cnum - e.start_of.pos_bol,
  e.end_of.pos_lnum,
  e.end_of.pos_cnum - e.end_of.pos_bol

let vistree_info_of_fundef f =
  vistree_info_of_exp f.body

let rec vistree_of_exp e =
  match e.exp_of with
  | EInt i ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("EInt(" ^ Int32.to_string i ^ ")")])
  | EFloat f ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("EFloat(" ^ string_of_float f ^ ")")])
  | EId id ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("EId(" ^ string_of_id id ^ ")")])
  | ESeq es ->
     VTList (vistree_info_of_exp e,
             (VTAtom "ESeq(" :: (intersperse (BatList.map vistree_of_exp es)
                                   (VTAtom ", "))
              @ [VTAtom ")"]))
  | ECall (id, es) ->
     VTList (vistree_info_of_exp e,
             (VTAtom ("ECall(" ^ string_of_id id) ::
                (intersperse (BatList.map vistree_of_exp es) (VTAtom ", "))
              @ [VTAtom ")"]))
  | ERef e ->
      VTList (vistree_info_of_exp e,
              [VTAtom "ERef("; vistree_of_exp e; VTAtom ")"])
  | EUnop (u, e) ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("EUnop(" ^ string_of_unop u ^ ", ");
              vistree_of_exp e; VTAtom ")"])
  | EBinop (b, e1, e2) ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("EBinop(" ^ string_of_binop b ^ ", ");
              vistree_of_exp e1; VTAtom ", ";
              vistree_of_exp e2; VTAtom ")"])
  | EIf (e1, e2, e3) ->
     VTList (vistree_info_of_exp e,
             [VTAtom "EIf("; vistree_of_exp e1; VTAtom ", ";
              vistree_of_exp e2; VTAtom ", ";
              vistree_of_exp e3; VTAtom ")"])
  | ELet (id, e1, e2) ->
     VTList (vistree_info_of_exp e,
             [VTAtom ("ELet(" ^ string_of_id id ^ ", ");
              vistree_of_exp e1; VTAtom ", ";
              vistree_of_exp e2; VTAtom ")"])
  | EScope e -> VTList (vistree_info_of_exp e,
                        [VTAtom "EScope("; vistree_of_exp e; VTAtom ")"])
  | EUnit -> VTList (vistree_info_of_exp e,
                     [VTAtom "EUnit"])
  | ETrue -> VTList (vistree_info_of_exp e,
                     [VTAtom "ETrue"])
  | EFalse -> VTList (vistree_info_of_exp e, [VTAtom "EFalse"])
  | EWhile (e1, e2) ->
     VTList (vistree_info_of_exp e,
             [VTAtom "EWhile("; vistree_of_exp e1; VTAtom ", ";
              vistree_of_exp e2; VTAtom ")"])

let vistree_of_fundef f =
  VTList (vistree_info_of_fundef f,
          [VTAtom ("fun " ^ string_of_id f.nm ^ "(" ^
                     String.concat ", " (BatList.map string_of_tid f.args) ^
                       ") : " ^ string_of_ty f.ret_ty ^ " {");
           vistree_of_exp f.body; VTAtom "}"])
         
let vistree_of_prog p =
  VTList ((-1, -1, -1, -1),
          (if not (BatList.is_empty p.fundefs) then ([VTAtom "fundefs: ["] @
            (intersperse (BatList.map vistree_of_fundef p.fundefs)
               (VTAtom ", ")) @ [VTAtom "]m "]) else
            []) @ [VTAtom "result: "; vistree_of_exp p.result])

(**********************)
(* Typing derivations *)
(**********************)

type typederiv =
  | TDStub

let json_of_typederiv = function
  | TDStub -> JSNull

type jsresponse =
  | JRError of string
  | JRSuccess of (string             (* putchar output *)
                  * value            (* result of program *)
                  * token list       (* tokens *)
                  * vistree          (* AST *)
                  * typederiv        (* typing derivation*)
                  * string           (* RTL *)
                  * string)          (* LLVM *)

let json_of_jsresponse = function
  | JRError msg -> JSAssoc [("error", JSString (String.escaped msg))]
  | JRSuccess (output, result, tokens, ast, tyderiv, rtl, llvm) ->
     JSAssoc [("output", JSString (String.escaped output));
              ("result", JSString (string_of_value result));
              ("tokens", JSList (BatList.map json_of_token tokens));
              ("ast", json_of_vistree ast);
              ("typederiv", json_of_typederiv tyderiv);
              ("rtl", JSString (String.escaped rtl));
              ("llvm", JSString (String.escaped llvm))]
