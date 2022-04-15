(* open Omigrate *)

let run ~source ~database = Omigrate.down ~source ~database |> Lwt_main.run

(* Command line interface *)

open Cmdliner

let doc = "Apply all down migrations."
let sdocs = Manpage.s_common_options
let exits = Common.exits
let envs = Common.envs

let man =
  [
    `S Manpage.s_description;
    `P
      "$(tname) applies all down migrations for which an up migration has been \
       run on the database.";
  ]

let info = Cmd.info "down" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ source = Common.source_arg
  and+ database = Common.database_arg in
  run ~source ~database |> Common.handle_errors

let cmd = Cmd.v info term
