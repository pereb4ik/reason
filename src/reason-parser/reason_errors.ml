(* There are three main categories of error:
   - _lexer errors_, thrown by Reason_lexer when the source **text is malformed**
     and no token can be produced
   - _concrete parsing errors_, thrown by the menhir parser / parsing loop
     when a **token is unexpected**
   - _abstract parsing errors_, thrown by hand-written semantic actions or
     further AST checks, when the source text was incorrect but this restriction
     was too fine to be captured by the grammar rules

   A fourth case is when unknown / unexpected error occurs.
*)

open Format

type lexing_error =
  | Illegal_character of char
  | Illegal_escape of string
  | Unterminated_comment of Location.t
  | Unterminated_string
  | Unterminated_string_in_comment of Location.t * Location.t
  | Keyword_as_label of string
  | Literal_overflow of string
  | Invalid_literal of string

type ast_error =
  | Not_expecting of Location.t * string
  | Other_syntax_error of string
  | Variable_in_scope of Location.t * string
  | Applicative_path of Location.t

type parsing_error = string

type reason_error =
  | Lexing_error of lexing_error
  | Parsing_error of parsing_error
  | Ast_error of ast_error

type reason_warning =
  (* Warnings caused by Ocaml-style syntax aka Camlisms *)
  | Ocaml_struct
  | Ocaml_match of Location.t * Location.t
  | Ocaml_do_done
  | Other_Ocaml_warning of string

exception Reason_error of reason_error * Location.t
exception Reason_warning of reason_warning * Location.t

let catch_errors
  : (reason_error * Location.t) list ref option ref
  = ref None

let raise_error error loc =
  match !catch_errors with
  | None -> raise (Reason_error (error, loc))
  | Some caught -> caught := (error, loc) :: !caught

let raise_fatal_error error loc =
  raise (Reason_error (error, loc))

let catch_warnings
  : (reason_warning * Location.t) list ref option ref
  = ref None

let report_warning_ref = ref (fun _ ~loc:_ _ -> ())

let raise_warning warn loc =
  match !catch_warnings with
  | None -> !report_warning_ref Format.err_formatter ~loc warn
  | Some caught -> caught := (warn, loc) :: !caught

let recover_non_fatal_errors f =
  let catch_errors0 = !catch_errors
  and catch_warnings0 = !catch_warnings in
  let errors = ref [] 
  and warnings = ref [] in
  catch_errors := Some errors;
  catch_warnings := Some warnings;
  let result =
    match f () with
    | x -> Result.Ok x
    | exception exn -> Result.Error exn
  in
  catch_errors := catch_errors0;
  catch_warnings := catch_warnings0;
  (result, (List.rev !errors, List.rev !warnings))

(* Report lexing errors *)

let format_lexing_error ppf = function
  | Illegal_character c ->
      fprintf ppf "Illegal character (%s)" (Char.escaped c)
  | Illegal_escape s ->
      fprintf ppf "Illegal backslash escape in string or character (%s)" s
  | Unterminated_comment _ ->
      fprintf ppf "Comment not terminated"
  | Unterminated_string ->
      fprintf ppf "String literal not terminated"
  | Unterminated_string_in_comment (_, loc) ->
      fprintf ppf "This comment contains an unterminated string literal@.\
                   %aString literal begins here"
        Ocaml_util.print_loc loc
  | Keyword_as_label kwd ->
      fprintf ppf "`%s' is a keyword, it cannot be used as label name" kwd
  | Literal_overflow ty ->
      fprintf ppf "Integer literal exceeds the range of representable \
                   integers of type %s" ty
  | Invalid_literal s ->
      fprintf ppf "Invalid literal %s" s

let format_parsing_error ppf msg =
  fprintf ppf "%s" msg

let format_ast_error ppf = function
  | Not_expecting (loc, nonterm) ->
    fprintf ppf
      "Syntax error: %a%s not expected."
      Ocaml_util.print_loc loc nonterm
  | Applicative_path loc ->
    fprintf ppf
      "Syntax error: %aapplicative paths of the form F(X).t \
       are not supported when the option -no-app-func is set."
      Ocaml_util.print_loc loc
  | Variable_in_scope (loc, var) ->
    fprintf ppf "%aIn this scoped type, variable '%s \
                 is reserved for the local type %s."
      Ocaml_util.print_loc loc var var
  | Other_syntax_error msg ->
    fprintf ppf "%s" msg

let format_error ppf = function
  | Lexing_error err -> format_lexing_error ppf err
  | Parsing_error err -> format_parsing_error ppf err
  | Ast_error err -> format_ast_error ppf err

let report_error ppf ~loc err =
  Format.fprintf ppf "@[%a@]@."
    (Ocaml_util.print_error loc format_error) err

let recover_parser_error f loc msg =
  if !Reason_config.recoverable
  then f loc msg
  else raise_fatal_error (Parsing_error msg) loc

let format_warning ppf = function
  | Ocaml_struct -> fprintf ppf
  "Ocaml-style module definition\nYou shoud use '{ }'."
  | Ocaml_match _ -> fprintf ppf 
  "Ocaml-style pattern matching\nYou shoud use 'switch { }'."
  | Ocaml_do_done -> fprintf ppf 
  "OCaml's 'do done'\nYou shoud use brackets instead"
  | Other_Ocaml_warning msg ->
    fprintf ppf "%s" msg

let report_warning ppf ~loc = function
  | Other_Ocaml_warning _ as warn ->
    Format.fprintf ppf "@[%a\n%a@]@."
    Ocaml_util.print_loc loc format_warning warn
  | warn ->
    Format.fprintf ppf "@[%a@]@."
  (Ocaml_util.print_error loc format_warning) warn

let () = (report_warning_ref := report_warning)

let () =
  Printexc.register_printer (function
      | Reason_error (err, loc) ->
        let _ = Format.flush_str_formatter () in
        report_error Format.str_formatter ~loc err;
        Some (Format.flush_str_formatter ())
      | Reason_warning (warn, loc) ->
        let _ = Format.flush_str_formatter () in
        report_warning Format.str_formatter ~loc warn;
        Some (Format.flush_str_formatter ())
      | _ -> None
    )

open Reason_omp.Ast_411

let str_eval_message text = {
  Parsetree.
  pstr_loc = Location.none;
  pstr_desc = Pstr_eval (
      { pexp_loc = Location.none;
        pexp_desc = Pexp_constant (Parsetree.Pconst_string (text, Location.none, None));
        pexp_attributes = [];
        pexp_loc_stack = [];
      },
      []
    );
}

let str_eval loc text = {
  Parsetree.
  pstr_loc = Location.none;
  pstr_desc = Pstr_eval (
      { pexp_loc = Location.none;
        pexp_desc = Pexp_constant (Parsetree.Pconst_string (text, loc, None));
        pexp_attributes = [];
        pexp_loc_stack = [];
      },
      []
    );
}

(** Generate a suitable extension node for Merlin's consumption,
    for the purposes of reporting a parse error - only used
    in recovery mode.
    Parse error will prevent Merlin from reporting subsequent errors, as they
    might be due wrong recovery decisions and will confuse the user.
 *)
let error_extension_node_from_recovery loc msg =
  recover_parser_error (fun loc msg ->
    let str = { Location. loc; txt = "merlin.syntax-error" } in
    let payload = [ str_eval_message msg ] in
    (str, Parsetree.PStr payload)
  ) loc msg

(** Generate a suitable extension node for OCaml consumption,
    for the purposes of reporting a syntax error.
    Contrary to [error_extension_node_from_recovery], these work both with
    OCaml and with Merlin.
 *)
let error_extension_node loc msg =
  recover_parser_error (fun loc msg ->
    let str = { Location. loc; txt = "ocaml.error" } in
    let payload = [ str_eval_message msg ] in
    (str, Parsetree.PStr payload)
  ) loc msg

let warning_attribute ?(sub=[]) loc msg =
  let structure = List.map (fun (loc, msg) -> str_eval loc msg) sub in
  Parsetree.{
    attr_name = { Location. loc; txt = "reason.warning" };
    attr_payload = Parsetree.PStr (str_eval_message msg :: structure);
    attr_loc = loc;
  }
