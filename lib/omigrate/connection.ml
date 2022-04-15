type conninfo = {
  host : string;
  user : string;
  pass : string;
  port : int;
  db : string;
}

let parse_uri s =
  let uri = Uri.of_string s in
  let host = Uri.host_with_default uri in
  let user = Uri.user uri |> Option.value ~default:"postgres" in
  let pass = Uri.password uri |> Option.value ~default:"postgres" in
  let port = Uri.port uri |> Option.value ~default:5432 in
  let db_result =
    match Uri.path uri with
    | "/" -> Error (Omigrate_error.bad_uri s)
    | path ->
        if Filename.dirname path <> "/" then Error (Omigrate_error.bad_uri s)
        else Ok (Filename.basename path)
  in
  Result.map (fun db -> { host; user; pass; port; db }) db_result
