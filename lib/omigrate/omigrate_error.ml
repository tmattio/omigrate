type t =
  [ `Unknown_driver of string
  | `Bad_uri of string
  | `Invalid_source of string
  ]

let to_string = function
  | `Unknown_driver s ->
    Printf.sprintf
      "The driver %S does not exist.\n\n\
       Hint: maybe you forgot to install the corresponding driver?."
      s
  | `Bad_uri s ->
    Printf.sprintf "The URI is not valid: %S." s
  | `Invalid_source s ->
    Printf.sprintf "The source is not valid: %S." s

let unknown_driver s = `Unknown_driver s

let bad_uri s = `Bad_uri s

let invalid_source s = `Invalid_source s
