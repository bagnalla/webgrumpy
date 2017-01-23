type json =
  | JSAssoc of (string * json) list
  | JSBool of bool
  | JSFloat of float
  | JSInt of int
  | JSList of json list
  | JSNull
  | JSString of string

(* Human-readable (could probably use some newlines somewhere) *)
let rec string_of_json_hum = function
  | JSAssoc props ->
     "{ " ^ String.concat ", " (BatList.map string_of_prop_hum props) ^ " }"
  | JSBool b -> string_of_bool b
  | JSFloat f -> string_of_float f
  | JSInt i -> string_of_int i
  | JSList lst ->
     "[" ^ String.concat ", " (BatList.map string_of_json_hum lst) ^ "]"
  | JSNull -> "null"
  | JSString s -> "\"" ^ s ^ "\""

 and string_of_prop_hum (k, v) =
   "\"" ^ k ^ "\": " ^ string_of_json_hum v

(* Machine-readable (more compressed) *)
let rec string_of_json_mach = function
  | JSAssoc props ->
     "{" ^ String.concat "," (BatList.map string_of_prop_mach props) ^ "}"
  | JSBool b -> string_of_bool b
  | JSFloat f -> string_of_float f
  | JSInt i -> string_of_int i
  | JSList lst ->
     "[" ^ String.concat "," (BatList.map string_of_json_mach lst) ^ "]"
  | JSNull -> "null"
  | JSString s -> "\"" ^ s ^ "\""

 and string_of_prop_mach (k, v) =
   "\"" ^ k ^ "\":" ^ string_of_json_mach v
