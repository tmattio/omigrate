module Db = struct
  (* The code in this module is extracted from https://github.com/ocurrent/ocurrent/blob/master/lib/db.ml.*)

  type t = {
    db : Sqlite3.db;
    begin_transaction : Sqlite3.stmt;
    commit : Sqlite3.stmt;
    rollback : Sqlite3.stmt;
  }

  let create ?mode database =
    let db = Sqlite3.db_open ?mode database in
    Sqlite3.busy_timeout db 1000;
    let begin_transaction = Sqlite3.prepare db "BEGIN TRANSACTION" in
    let commit = Sqlite3.prepare db "COMMIT" in
    let rollback = Sqlite3.prepare db "ROLLBACK" in
    { db; begin_transaction; commit; rollback }

  let close t = Sqlite3.db_close t.db

  let or_fail db ~cmd res =
    match res with
    | Sqlite3.Rc.OK -> ()
    | err ->
        let msg =
          Printf.sprintf "Sqlite3 driver: [or_fail] [%s] %s (executing %S)"
            (Sqlite3.Rc.to_string err) (Sqlite3.errmsg db) cmd
        in
        failwith msg

  let no_callback _ =
    failwith "Sqlite3 driver: [no_callback] exec used with a query!"

  let exec_stmt t ?(cb = no_callback) stmt =
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | Sqlite3.Rc.ROW ->
          let cols = Sqlite3.data_count stmt in
          cb (List.init cols (fun i -> Sqlite3.column stmt i));
          loop ()
      | err ->
          let msg =
            Printf.sprintf "Sqlite3 driver: [exec_stmt] [%s] %s"
              (Sqlite3.Rc.to_string err) (Sqlite3.errmsg t.db)
          in
          failwith msg
    in
    loop ()

  let bind t stmt values =
    Sqlite3.reset stmt |> or_fail t.db ~cmd:"reset";
    List.iteri
      (fun i v -> Sqlite3.bind stmt (i + 1) v |> or_fail t.db ~cmd:"bind")
      values

  let exec t stmt values =
    bind t stmt values;
    exec_stmt t stmt

  let query t stmt values =
    bind t stmt values;
    let results = ref [] in
    let cb row = results := row :: !results in
    exec_stmt t ~cb stmt;
    List.rev !results

  let with_transaction t fn =
    exec t t.begin_transaction [];
    match fn () with
    | x ->
        exec t t.commit [];
        x
    | exception exn ->
        exec t t.rollback [];
        raise exn
end

module T = struct
  let migrations_table = "schema_migrations"
  let quote_statement s = "\"" ^ s ^ "\""

  let to_opt_pair x y =
    match (x, y) with Some x, Some y -> Some (x, y) | _ -> None

  let database_exists database =
    let open Lwt.Syntax in
    let* () = Logs_lwt.debug (fun m -> m "Querying existing databases") in
    Lwt.catch
      (fun () ->
        let+ st = Lwt_unix.stat database in
        match st with Unix.{ st_kind = S_REG; _ } -> true | _ -> false)
      (function
        | Unix.Unix_error (Unix.ENOENT, _, _) -> Lwt.return_false
        | exn -> Lwt.fail exn)

  let delete_database database = Lwt_unix.unlink database

  let ensure_version_table_exists t =
    let open Lwt.Syntax in
    let* () = Logs_lwt.info (fun m -> m "Creating the migration table") in
    let stmt =
      Sqlite3.prepare t.Db.db
        ("CREATE TABLE IF NOT EXISTS "
        ^ quote_statement migrations_table
        ^ "(version bigint NOT NULL, dirty boolean NOT NULL, CONSTRAINT \
           schema_migrations_pkey PRIMARY KEY (version));")
    in
    Db.with_transaction t (fun () -> Db.exec t stmt []) |> Lwt.return

  let up ~host:_ ?port:_ ?user:_ ?password:_ ~database migration =
    let open Lwt.Syntax in
    let t = Db.create ~mode:`NO_CREATE database in
    Db.with_transaction t (fun () ->
        let version = migration.Omigrate.Migration.version in
        let* () =
          Logs_lwt.info (fun m -> m "Applying up migration %Ld" version)
        in
        let _ =
          let stmt = Sqlite3.prepare t.Db.db migration.Omigrate.Migration.up in
          Db.query t stmt []
        in
        let* () =
          Logs_lwt.debug (fun m ->
              m "Inserting version %Ld in migration table" version)
        in
        let () =
          let stmt =
            Sqlite3.prepare t.db
              ("DELETE FROM " ^ quote_statement migrations_table ^ ";")
          in
          Db.exec t stmt []
        in
        let () =
          let stmt =
            Sqlite3.prepare t.db
              ("INSERT INTO "
              ^ quote_statement migrations_table
              ^ " (version, dirty) VALUES (?, ?);")
          in
          Db.exec t stmt
            [
              Sqlite3.Data.opt_int64 (Some version);
              Sqlite3.Data.opt_bool (Some false);
            ]
        in
        Lwt.return_unit)

  let down ~host:_ ?port:_ ?user:_ ?password:_ ~database ?previous migration =
    let open Lwt.Syntax in
    let t = Db.create ~mode:`NO_CREATE database in
    Db.with_transaction t (fun () ->
        let version = migration.Omigrate.Migration.version in
        let* () =
          Logs_lwt.info (fun m -> m "Applying down migration %Ld" version)
        in
        let _ =
          let stmt =
            Sqlite3.prepare t.Db.db migration.Omigrate.Migration.down
          in
          Db.query t stmt []
        in
        let* () =
          Logs_lwt.debug (fun m ->
              m "Removing version %Ld in migration table" version)
        in
        let () =
          let stmt =
            Sqlite3.prepare t.db
              ("DELETE FROM " ^ quote_statement migrations_table ^ ";")
          in
          Db.exec t stmt []
        in
        match previous with
        | None ->
            let* () =
              Logs_lwt.debug (fun m -> m "Migration table left empty")
            in
            Lwt.return_unit
        | Some previous ->
            let previous_version = previous.Omigrate.Migration.version in
            let* () =
              Logs_lwt.debug (fun m ->
                  m "Shifting migration table version to %Ld" previous_version)
            in
            let () =
              let stmt =
                Sqlite3.prepare t.db
                  ("INSERT INTO "
                  ^ quote_statement migrations_table
                  ^ " (version, dirty) VALUES (?, ?);")
              in
              Db.exec t stmt
                [
                  Sqlite3.Data.opt_int64 (Some previous_version);
                  Sqlite3.Data.opt_bool (Some false);
                ]
            in
            Lwt.return_unit)

  let create ~host:_ ?port:_ ?user:_ ?password:_ database =
    let open Lwt.Syntax in
    let* exists = database_exists database in
    let t = ref None in
    let* () =
      if exists then Logs_lwt.info (fun m -> m "Database already exists")
      else
        let* () = Logs_lwt.info (fun m -> m "Creating the database") in
        t := Some (Db.create database);
        Lwt.return_unit
    in
    let t = Option.value !t ~default:(Db.create ~mode:`NO_CREATE database) in
    ensure_version_table_exists t

  let drop ~host:_ ?port:_ ?user:_ ?password:_ database =
    let open Lwt.Syntax in
    let* exist = database_exists database in
    if not exist then Logs_lwt.info (fun m -> m "Database does not exist")
    else
      let* () = Logs_lwt.info (fun m -> m "Deleting the database") in
      delete_database database

  let version ~host:_ ?port:_ ?user:_ ?password:_ ~database () =
    let open Lwt.Syntax in
    let* () = Logs_lwt.debug (fun m -> m "Querying all versions") in
    let t = Db.create ~mode:`NO_CREATE database in
    let stmt =
      Sqlite3.prepare t.Db.db
        ("SELECT version, dirty FROM " ^ quote_statement migrations_table)
    in
    match Db.query t stmt [] with
    | [ [ version; dirty ] ] ->
        let version = Sqlite3.Data.to_int64 version in
        let dirty = Sqlite3.Data.to_bool dirty in
        to_opt_pair version dirty |> Lwt.return
    | _ -> Lwt.return_none

  let parse_uri s =
    let module Omigrate_error = Omigrate.Error in
    let module Connection = Omigrate.Driver.Connection in
    let uri = Uri.of_string s in
    let host = Uri.host_with_default uri in
    let user = Uri.user uri in
    let pass = Uri.password uri in
    let port = Uri.port uri in
    let db_result =
      match Uri.path uri with
      | "/" -> Error (Omigrate_error.bad_uri s)
      | path -> Ok path
    in
    Result.map (fun db -> Connection.{ host; user; pass; port; db }) db_result
end

let () = Omigrate.Driver.register "sqlite3" (module T)
