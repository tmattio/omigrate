module T = struct
  let default_user = "postgres"
  let default_password = "postgres"
  let default_port = 5432
  let migrations_table = "schema_migrations"
  let quote_statement s = "\"" ^ s ^ "\""

  let ensure_version_table_exists ~conn =
    let open Lwt.Syntax in
    let* () =
      Logs_lwt.info (fun m -> m "Creating the migrations table if not exists")
    in
    Pgx_lwt_unix.execute_unit conn
      ("CREATE TABLE IF NOT EXISTS "
      ^ quote_statement migrations_table
      ^ "(version bigint NOT NULL, dirty boolean NOT NULL, CONSTRAINT \
         schema_migrations_pkey PRIMARY KEY (version));")

  let with_conn ~host ?(port = default_port) ?(user = default_user)
      ?(password = default_password) ?database f =
    let open Lwt.Syntax in
    let* () =
      Logs_lwt.debug (fun m ->
          m "Opening a conection on postgres://%s:%s@%s:%d/%a" user password
            host port
            (Format.pp_print_option Format.pp_print_string)
            database)
    in
    Pgx_lwt_unix.with_conn ~host ~port ~user ~password ?database f

  let with_transaction ~host ?(port = default_port) ?user ?password ?database f
      =
    with_conn ~host ~port ?user ?password ?database (fun conn ->
        Pgx_lwt_unix.with_transaction conn f)

  let database_exists ~conn database =
    let open Lwt.Syntax in
    let* () = Logs_lwt.debug (fun m -> m "Querying existing databases") in
    let+ result =
      Pgx_lwt_unix.execute
        ~params:[ Pgx.Value.(of_string database) ]
        conn
        "SELECT EXISTS(SELECT datname FROM pg_catalog.pg_database WHERE \
         datname = $1);"
    in
    result |> List.hd |> List.hd |> Pgx.Value.to_bool_exn

  let up ~host ?(port = default_port) ?user ?password ~database migration =
    let open Lwt.Syntax in
    with_transaction ~host ~port ?user ?password ~database (fun conn ->
        let version = migration.Omigrate.Migration.version in
        let* () =
          Logs_lwt.info (fun m -> m "Applying up migration %Ld" version)
        in
        let* _ =
          Pgx_lwt_unix.simple_query conn migration.Omigrate.Migration.up
        in
        let* () =
          Logs_lwt.debug (fun m ->
              m "Inserting version %Ld in migration table" version)
        in
        let* () =
          Pgx_lwt_unix.execute_unit conn
            ("TRUNCATE " ^ quote_statement migrations_table ^ ";")
        in
        Pgx_lwt_unix.execute_unit
          ~params:[ Pgx.Value.(of_int64 version); Pgx.Value.(of_bool false) ]
          conn
          ("INSERT INTO "
          ^ quote_statement migrations_table
          ^ " (version, dirty) VALUES ($1, $2);"))

  let down ~host ?(port = default_port) ?user ?password ~database ?previous
      migration =
    let open Lwt.Syntax in
    with_transaction ~host ~port ?user ?password ~database (fun conn ->
        let version = migration.Omigrate.Migration.version in
        let* () =
          Logs_lwt.info (fun m -> m "Applying down migration %Ld" version)
        in
        let* _ =
          Pgx_lwt_unix.simple_query conn migration.Omigrate.Migration.down
        in
        let* () =
          Logs_lwt.debug (fun m ->
              m "Removing version %Ld from migration table" version)
        in
        let* () =
          Pgx_lwt_unix.execute_unit conn
            ("TRUNCATE " ^ quote_statement migrations_table ^ ";")
        in
        match previous with
        | None -> Lwt.return ()
        | Some previous ->
            let previous_version = previous.Omigrate.Migration.version in
            Pgx_lwt_unix.execute_unit
              ~params:
                [
                  Pgx.Value.(of_int64 previous_version);
                  Pgx.Value.(of_bool false);
                ]
              conn
              ("INSERT INTO "
              ^ quote_statement migrations_table
              ^ " (version, dirty) VALUES ($1, $2);"))

  let create ~host ?(port = default_port) ?user ?password database =
    let open Lwt.Syntax in
    let* () =
      with_conn ~host ~port ?user ?password (fun conn ->
          let* database_exists = database_exists ~conn database in
          if database_exists then
            Logs_lwt.info (fun m -> m "Database already exists")
          else
            let* () = Logs_lwt.info (fun m -> m "Creating the database") in
            Pgx_lwt_unix.execute_unit conn
              ("CREATE DATABASE " ^ quote_statement database ^ ";"))
    in
    with_conn ~host ~port ?user ?password ~database (fun conn ->
        ensure_version_table_exists ~conn)

  let drop ~host ?(port = default_port) ?user ?password database =
    let open Lwt.Syntax in
    with_conn ~host ~port ?user ?password (fun conn ->
        let* database_exists = database_exists ~conn database in
        if not database_exists then
          Logs_lwt.info (fun m -> m "Database does not exists")
        else
          let* () = Logs_lwt.info (fun m -> m "Deleting the database") in
          Pgx_lwt_unix.execute_unit conn
            ("DROP DATABASE " ^ quote_statement database ^ ";"))

  let version ~host ?(port = default_port) ?user ?password ~database () =
    with_conn ~host ~port ?user ?password ~database (fun conn ->
        let open Lwt.Syntax in
        let* () = Logs_lwt.debug (fun m -> m "Querying all versions") in
        let+ result =
          Pgx_lwt_unix.execute conn
            ("SELECT version, dirty FROM "
            ^ quote_statement migrations_table
            ^ "ORDER BY version DESC LIMIT 1;")
        in
        match result with
        | [ [ version; dirty ] ] ->
            Some (Pgx.Value.to_int64_exn version, Pgx.Value.to_bool_exn dirty)
        | _ -> None)

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
      | path ->
          if Filename.dirname path <> "/" then Error (Omigrate_error.bad_uri s)
          else Ok (Filename.basename path)
    in
    Result.map (fun db -> Connection.{ host; user; pass; port; db }) db_result
end

let () =
  Omigrate.Driver.register "postgres" (module T);
  Omigrate.Driver.register "postgresql" (module T)
