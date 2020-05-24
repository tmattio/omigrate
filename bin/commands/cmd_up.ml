(* open Omigrate *)

let run ~source ~database = Omigrate.up ~source ~database |> Lwt_main.run

(* Command line interface *)

open Cmdliner

let doc = "Apply all up migrations."

let sdocs = Manpage.s_common_options

let exits = Common.exits

let envs = Common.envs

let man =
  [ `S Manpage.s_description
  ; `P
      "$(tname) applies all up migrations that haven't been applied on the \
       database."
  ]

let info = Term.info "up" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ source = Common.source_arg
  and+ database = Common.database_arg in
  run ~source ~database |> Common.handle_errors

let cmd = term, info
