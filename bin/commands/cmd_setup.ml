let run ~force ~source ~database =
  let open Lwt_result.Syntax in
  let lwt =
    let* () = Omigrate.create ~database in
    Omigrate.up ~force ~source ~database ()
  in
  Lwt_main.run lwt

(* Command line interface *)

open Cmdliner

let doc = "Create the database and run all the migrations."
let sdocs = Manpage.s_common_options
let exits = Common.exits
let envs = Common.envs

let man =
  [
    `S Manpage.s_description;
    `P
      "$(tname) creates the database if it does not exist, and run all up \
       migrations.";
  ]

let info = Cmd.info "setup" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ source = Common.source_arg
  and+ database = Common.database_arg
  and+ force = Common.force_arg in
  run ~force ~source ~database |> Common.handle_errors

let cmd = Cmd.v info term
