open Cmdliner

let cmds =
  [
    Cmd_create.cmd;
    Cmd_down.cmd;
    Cmd_drop.cmd;
    Cmd_up.cmd;
    Cmd_ls.cmd;
    Cmd_setup.cmd;
  ]

(* Command line interface *)

let doc = "Database migrations for Reason and OCaml"
let sdocs = Manpage.s_common_options
let exits = Common.exits
let envs = Common.envs

let man =
  [
    `S Manpage.s_description;
    `P "Database migrations for Reason and OCaml";
    `S Manpage.s_commands;
    `S Manpage.s_common_options;
    `S Manpage.s_exit_status;
    `P "These environment variables affect the execution of $(mname):";
    `S Manpage.s_environment;
    `S Manpage.s_bugs;
    `P "File bug reports at $(i,%%PKG_ISSUES%%)";
    `S Manpage.s_authors;
    `P "Thibaut Mattio, $(i,https://github.com/tmattio)";
  ]

let default =
  let open Common.Let_syntax in
  Term.ret
  @@ let+ _ = Common.term in
     `Help (`Pager, None)

let info =
  Cmd.info "omigrate" ~version:"%%VERSION%%" ~doc ~sdocs ~exits ~man ~envs

let () =
  let main = Cmdliner.Cmd.group ~default info cmds in
  Stdlib.exit @@ Cmd.eval' main
