open Core
open P4stf.Test
open Petr4.Stf

let include_dir = [$include_path$]

let run_stf_alcotest p4_file =
  let stf_file = Stdlib.Filename.remove_extension p4_file ^ ".stf" in
  let cfg = Petr4.Pass.mk_check_only include_dir p4_file in
  let p4_prog = Petr4.Unix.Driver.run_checker cfg
  |> Petr4.Common.handle_error in
  let expected, results = run_stf stf_file p4_prog in
  List.zip_exn expected results
  |> List.iter ~f:(fun (p_exp, p) ->
    Alcotest.(testable (Fmt.pair ~sep:Fmt.sp Fmt.string Fmt.string) packet_equal |> check) "packet test" p_exp p)

let path_test_arg =
  Cmdliner.Arg.(required & opt (some string) None & info ["t"] ~doc:"the path to the folder with the stf file for the p4_lsp test")
      
let () =
  Alcotest.run_with_args "Stf-tests" path_test_arg [
    "p4_lsp stf tests", ["file testing", `Quick, run_stf_alcotest]
  ]
