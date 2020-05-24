type t = Local_dir of string

module Local_dir = struct
  let migration_of_file f =
    let basename = Filename.basename f in
    match String.split_on_char basename ~sep:'_' with
    | hd :: _ ->
      let version = hd in
      let rest =
        String.sub
        basename
          ~pos:(String.length hd + 1)
          ~len:(String.length basename - (String.length hd + 1))
      in
      (match String.split_on_char rest ~sep:'.' |> List.rev with
      | [ "sql"; "up"; name ] ->
        let ic = open_in f in
        let up = really_input_string ic (in_channel_length ic) in
        close_in ic;
        let ic =
          open_in (String.sub f ~pos:0 ~len:(String.length f - 7) ^ ".down.sql")
        in
        let down = really_input_string ic (in_channel_length ic) in
        close_in ic;
        Some Migration.{ version = Int64.of_string version; name; up; down }
      | _ ->
        None)
    | _ ->
      None

  let versions dir =
    Sys.readdir dir
    |> Array.to_list
    |> List.map ~f:(Filename.concat dir)
    |> List.filter_map ~f:migration_of_file
end

let of_string s =
  if Sys.file_exists s && Sys.is_directory s then
    Ok (Local_dir s)
  else
    Error (Omigrate_error.invalid_source s)

let versions = function Local_dir s -> Local_dir.versions s
