(lang dune 3.0)
(generate_opam_files true)
(cram enable)

(name omigrate)

(source
 (github tmattio/omigrate))

(documentation "https://tmattio.github.io/omigrate/")
(license MIT)
(authors "Thibaut Mattio")
(maintainers "Thibaut Mattio")

(package
 (name omigrate)
 (synopsis "Database migrations for Reason and OCaml")
 (description "Database migrations for Reason and OCaml")
 (depends
  (ocaml
   (>= 4.08.0))
  (result
    (>= 1.5))
  (lwt
   (>= 5.3.0))
  uri
  (cmdliner
   (>= 1.1.0))
  logs
  fmt
  ; Postgres Driver
  pgx
  pgx_lwt_unix
  ; Sqlite3 Driver
  (sqlite3 (>= 5.0.1))))
