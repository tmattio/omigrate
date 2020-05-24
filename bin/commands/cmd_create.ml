let run ~dir ~name =
  let () =
    if Sys.file_exists dir && Sys.is_directory dir then
      ()
    else
      Unix.mkdir dir 0o755
  in
  let tm = Unix.gmtime (Unix.time ()) in
  let date =
    Printf.sprintf
      "%d%02d%02d%02d%02d%02d"
      (1900 + tm.Unix.tm_year)
      tm.Unix.tm_mon
      tm.Unix.tm_mday
      tm.Unix.tm_hour
      tm.Unix.tm_min
      tm.Unix.tm_sec
  in
  let migration_name = Printf.sprintf "%s_%s" date name in
  open_out (Filename.concat dir (Printf.sprintf "%s.up.sql" migration_name))
  |> close_out;
  open_out (Filename.concat dir (Printf.sprintf "%s.down.sql" migration_name))
  |> close_out;
  Ok ()

(* Command line interface *)

open Cmdliner

let doc = "Create a new migration and prepend it with a timestamp."

let sdocs = Manpage.s_common_options

let exits = Common.exits

let envs = Common.envs

let man =
  [ `S Manpage.s_description
  ; `P
      "$(tname) generates a new up and down migration in the given source and \
       prepends the name of the migrations with a timestamp."
  ]

let info = Term.info "create" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ dir =
    let doc = "The directory where the migration will be generated." in
    Arg.(
      required & opt (some string) None & info [ "dir"; "d" ] ~docv:"DIR" ~doc)
  and+ name =
    let doc =
      "The name of the migration. Usually the action performed by the \
       migration, for instance, `create_users_table`"
    in
    let docv = "NAME" in
    Arg.(required & pos 0 (some string) None & info [] ~doc ~docv)
  in
  run ~dir ~name |> Common.handle_errors

let cmd = term, info
