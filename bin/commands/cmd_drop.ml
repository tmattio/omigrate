(* open Omigrate *)

let run ~database = Omigrate.drop ~database |> Lwt_main.run

(* Command line interface *)

open Cmdliner

let doc = "Delete the database."

let sdocs = Manpage.s_common_options

let exits = Common.exits

let envs = Common.envs

let man =
  [ `S Manpage.s_description; `P "$(tname) deletes the database if it exists." ]

let info = Term.info "drop" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ database = Common.database_arg in
  run ~database |> Common.handle_errors

let cmd = term, info
