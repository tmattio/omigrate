module type S = sig
  val up
    :  host:string
    -> port:int
    -> user:string
    -> password:string
    -> database:string
    -> Migration.t
    -> unit Lwt.t

  val down
    :  host:string
    -> port:int
    -> user:string
    -> password:string
    -> database:string
    -> Migration.t
    -> unit Lwt.t

  val create
    :  host:string
    -> port:int
    -> user:string
    -> password:string
    -> string
    -> unit Lwt.t

  val drop
    :  host:string
    -> port:int
    -> user:string
    -> password:string
    -> string
    -> unit Lwt.t

  val versions
    :  host:string
    -> port:int
    -> user:string
    -> password:string
    -> database:string
    -> unit
    -> int64 list Lwt.t
end

let drivers = Hashtbl.create 1

let load scheme =
  try Ok (Hashtbl.find drivers scheme) with
  | Not_found ->
    Error (Omigrate_error.unknown_driver scheme)

let load_from_uri s =
  let uri = Uri.of_string s in
  match Uri.scheme uri with
  | None ->
    Error (Omigrate_error.bad_uri s)
  | Some scheme ->
    load scheme

let register scheme (module T : S) = Hashtbl.add drivers scheme (module T : S)
