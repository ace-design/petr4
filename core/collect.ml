module I = Petr4.Info
open Petr4.Prog
open Core_kernel
open Util
module Info = I

(** Collects all error and match-kind declarations.
  INVARIANT: The output program contains no
    match-kind nor error declarations. *)
let rec collect
  (Program p) : Ast.id list * Ast.match_kind list * program =
  p
  |> List.fold_left
      ~f:begin fun
          (acc :Ast.id list * Ast.match_kind list * Declaration.t list)
          (d : Declaration.t) ->
            let open Declaration in
            acc |>
            match d with
            | _, Error {members}     -> Tuple.T3.map_fst
              ~f:begin fun errors ->
                List.map ~f:snd members @ errors end
            | _, MatchKind {members} -> Tuple.T3.map_snd
              ~f:begin fun match_kinds ->
                List.map ~f:(Ast.mk $$ snd) members @ match_kinds end
            | i, Parser prsr         ->
              fun (errors, match_kinds, rev_prog) ->
                let pes, pmks, Program lcls = collect (Program prsr.locals) in
                pes @ errors, pmks @ match_kinds,
                (i, Parser { prsr with locals = lcls}) :: rev_prog
            | i, Control ctrl        ->
              fun (errors, match_kinds, rev_prog) ->
                let ces, cmks, Program lcls = collect (Program ctrl.locals) in
                ces @ errors, cmks @ match_kinds,
                (i, Control { ctrl with locals = lcls }) :: rev_prog
            | _                      -> Tuple.T3.map_trd
              ~f:begin fun rev_prog -> d :: rev_prog end
          end
      ~init:([],[],[])
  |> Tuple.T3.map_trd ~f:begin pgm $$ List.rev end
