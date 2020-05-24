(lang dune 2.0)

(name omigrate)

(source
 (github tmattio/omigrate))

(license MIT)

(authors "Thibaut Mattio")

(maintainers "Thibaut Mattio")

(generate_opam_files true)

(package
 (name omigrate)
 (synopsis "Database migrations for Reason and OCaml")
 (description "Database migrations for Reason and OCaml")
 (depends
  (ocaml
   (>= 4.08.0))
  (dune
   (>= 2.0))
  (odoc :with-doc)
  (lwt
   (>= 5.3.0))
  uri
  cmdliner
  logs
  fmt))

(package
 (name omigrate.postgres)
 (synopsis "Postgres driver for OCaml Migrate")
 (description "Postgres driver for OCaml Migrate")
 (depends
  (ocaml
   (>= 4.08.0))
  (dune
   (>= 2.0))
  (lwt
   (>= 5.3.0))
  pgx
  pgx_lwt_unix))
