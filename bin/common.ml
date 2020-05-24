open Cmdliner

module Let_syntax = struct
  let ( let+ ) t f = Term.(const f $ t)

  let ( and+ ) a b = Term.(const (fun x y -> x, y) $ a $ b)
end

open Let_syntax

let source_arg =
  let doc =
    "The location of the migrations. For now, only local directory can be used \
     as sources."
  in
  let env = Arg.env_var "OMIGRATE_SOURCE" ~doc in
  Arg.(
    required
    & opt (some string) None
    & info [ "source"; "s" ] ~docv:"SOURCE" ~doc ~env)

let database_arg =
  let doc = "The database to run the migrations on." in
  let env = Arg.env_var "OMIGRATE_DATABASE" ~doc in
  Arg.(
    required
    & opt (some string) None
    & info [ "database"; "d" ] ~docv:"DATABASE" ~doc ~env)

let envs = []

let term =
  let+ log_level =
    let env = Arg.env_var "OMIGRATE_VERBOSITY" in
    Logs_cli.level ~docs:Manpage.s_common_options ~env ()
  in
  Fmt_tty.setup_std_outputs ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~app:Fmt.stdout ());
  0

let error_to_code = function
  | `Bad_uri _ ->
    4
  | `Unknown_driver _ ->
    5
  | `Invalid_source _ ->
    6

let handle_errors = function
  | Ok () ->
    if Logs.err_count () > 0 then 3 else 0
  | Error err ->
    Logs.err (fun m -> m "%s" (Omigrate.Error.to_string err));
    error_to_code err

let exits =
  Term.exit_info 3 ~doc:"on indiscriminate errors reported on stderr."
  :: Term.exit_info 4 ~doc:"on bad URI format."
  :: Term.exit_info 5 ~doc:"on unknown database driver."
  :: Term.exit_info 6 ~doc:"on invalid migration source."
  :: Term.default_exits
