let pp_green : string Fmt.t =
  let open Fmt in
  styled (`Fg `Green) Fmt.string

let pp_red : string Fmt.t =
  let open Fmt in
  styled (`Fg `Red) Fmt.string

let run ~source ~database =
  let source_versions = Omigrate.source_versions ~source in
  match (Omigrate.db_version ~database |> Lwt_main.run, source_versions) with
  | Error e, _ -> Error e
  | _, Error e -> Error e
  | Ok None, _ ->
      Logs.app (fun m -> m "No migration have been applied.");
      Ok ()
  | Ok (Some (db_version, _dirty)), Ok source_versions ->
      let () =
        source_versions
        |> List.sort (fun s1 s2 ->
               Int64.compare s1.Omigrate.Migration.version
                 s2.Omigrate.Migration.version)
        |> List.iter (fun (s : Omigrate.Migration.t) ->
               if Int64.compare s.version db_version <= 0 then
                 Logs.app (fun m ->
                     m "%s - %a" s.Omigrate.Migration.name pp_green "applied")
               else
                 Logs.app (fun m ->
                     m "%s - %a" s.Omigrate.Migration.name pp_red "not applied"))
      in
      Ok ()

(* Command line interface *)

open Cmdliner

let doc = "List the migrations with their state."
let sdocs = Manpage.s_common_options
let exits = Common.exits
let envs = Common.envs

let man =
  [
    `S Manpage.s_description;
    `P
      "$(tname) lists the migrations with their state (applied or not applied).";
  ]

let info = Cmd.info "ls" ~doc ~sdocs ~exits ~envs ~man

let term =
  let open Common.Let_syntax in
  let+ _term = Common.term
  and+ source = Common.source_arg
  and+ database = Common.database_arg in
  run ~source ~database |> Common.handle_errors

let cmd = Cmd.v info term
