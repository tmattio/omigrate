type t = { version : int64; name : string; up : string; down : string }

let compare t1 t2 = Int64.compare t1.version t2.version
