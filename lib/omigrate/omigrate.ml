module Connection = Driver.Connection

let with_driver ~f database =
  let open Lwt_result.Syntax in
  let* () =
    Logs_lwt.debug (fun m -> m "Loading the driver from the URI")
    |> Lwt_result.ok
  in
  let* driver = Driver.load_from_uri database |> Lwt.return in
  let module D = (val driver) in
  let* conninfo = D.parse_uri database |> Lwt.return in
  f (module D : Driver.S) conninfo

let db_version ~database =
  with_driver database ~f:(fun (module Driver) conninfo ->
      Driver.version ~host:conninfo.Connection.host
        ?port:conninfo.Connection.port ?user:conninfo.Connection.user
        ?password:conninfo.Connection.pass ~database:conninfo.Connection.db ()
      |> Lwt_result.ok)

let fetch_version (module Driver : Driver.S) ~bound force conninfo =
  let open Lwt.Syntax in
  if not force then
    let* result =
      Driver.version ~host:conninfo.Connection.host
        ?port:conninfo.Connection.port ?user:conninfo.Connection.user
        ?password:conninfo.Connection.pass ~database:conninfo.Connection.db ()
    in
    match result with
    | Some (version, _) -> Lwt.return_ok version
    | None -> Lwt.return_ok Int64.zero
  else Lwt.return_ok bound

let source_versions ~source =
  let open Std.Result.Syntax in
  let+ source = Source.of_string source in
  Source.versions source

let up ?(force = false) ~source ~database () =
  let open Lwt_result.Syntax in
  let* source_versions = source_versions ~source |> Lwt.return in
  with_driver database ~f:(fun (module Driver) conninfo ->
      let* origin =
        fetch_version ~bound:Int64.zero (module Driver) force conninfo
      in
      source_versions
      |> List.filter (fun s -> Int64.compare s.Migration.version origin > 0)
      |> List.sort (fun s1 s2 ->
             Int64.compare s1.Migration.version s2.Migration.version)
      |> List.fold_left
           (fun acc s ->
             Lwt.bind acc (fun () ->
                 Driver.up ~host:conninfo.Connection.host
                   ?port:conninfo.Connection.port ?user:conninfo.Connection.user
                   ?password:conninfo.Connection.pass
                   ~database:conninfo.Connection.db s))
           (Lwt.return ())
      |> Lwt_result.ok)

let down ?(force = false) ~source ~database () =
  let open Lwt_result.Syntax in
  let* source_versions = source_versions ~source |> Lwt.return in
  with_driver database ~f:(fun (module Driver) conninfo ->
      let* origin =
        fetch_version ~bound:Int64.max_int (module Driver) force conninfo
      in
      source_versions
      |> List.filter (fun s -> Int64.compare s.Migration.version origin <= 0)
      |> List.sort (fun s1 s2 ->
             Int64.compare s1.Migration.version s2.Migration.version)
      |> List.rev
      |> List.fold_left
           (fun acc s ->
             Lwt.bind acc (fun () ->
                 Driver.down ~host:conninfo.Connection.host
                   ?port:conninfo.Connection.port ?user:conninfo.Connection.user
                   ?password:conninfo.Connection.pass
                   ~database:conninfo.Connection.db s))
           (Lwt.return ())
      |> Lwt_result.ok)

let create ~database =
  with_driver database ~f:(fun (module Driver) conninfo ->
      Driver.create ~host:conninfo.Connection.host
        ?port:conninfo.Connection.port ?user:conninfo.Connection.user
        ?password:conninfo.Connection.pass conninfo.Connection.db
      |> Lwt_result.ok)

let drop ~database =
  with_driver database ~f:(fun (module Driver) conninfo ->
      Driver.drop ~host:conninfo.Connection.host ?port:conninfo.Connection.port
        ?user:conninfo.Connection.user ?password:conninfo.Connection.pass
        conninfo.Connection.db
      |> Lwt_result.ok)

module Error = Omigrate_error
module Migration = Migration

module Driver : sig
  module type S

  module Connection : sig
    type t = Driver.Connection.t = {
      host : string;
      user : string option;
      pass : string option;
      port : int option;
      db : string;
    }
  end

  val load : string -> ((module Driver.S), Error.t) Result.t
  val load_from_uri : string -> ((module Driver.S), Error.t) Result.t
  val register : string -> (module Driver.S) -> unit
  val list : unit -> string list
end =
  Driver
