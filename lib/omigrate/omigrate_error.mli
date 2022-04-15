type t =
  [ `Unknown_driver of string | `Bad_uri of string | `Invalid_source of string ]

val to_string : t -> string
val unknown_driver : string -> t
val bad_uri : string -> t
val invalid_source : string -> t
