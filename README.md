# OCaml Migrate

[![Actions Status](https://github.com/tmattio/omigrate/workflows/CI/badge.svg)](https://github.com/tmattio/omigrate/actions)

Database migrations for Reason and OCaml

## Drivers

- PosgreSQL (`omigrate.postgres`)

## Installation

### Using Opam

```bash
opam install omigrate
```

### Using Esy

```bash
esy add @opam/omigrate
```

## Usage

### `omigrate create --dir DIR NAME`

Create a new migration and prepend it with a timestamp.

### `omigrate ls --source SOURCE --database DATABASE`

List the migrations with their state.

### `omigrate up --source SOURCE --database DATABASE`

Apply all up migrations.

### `omigrate down --source SOURCE --database DATABASE`

Apply all down migrations.

### `omigrate setup --source SOURCE --database DATABASE`

Setup the database and run all the migrations.

### `omigrate drop --database DATABASE`

Delete the database.

## Contributing

Take a look at our [Contributing Guide](CONTRIBUTING.md).

# Example

An example of migrations that create `users` and `users_token` table for an authentication system is available in [example](./example)
