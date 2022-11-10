Ensure sqlite table list is empty
  $ sqlite3 test.db ".tables"

Execute the sqlite migrations
  $ omigrate setup -d "sqlite3://$PWD/test.db" -s ./sqlite3 -vv
  omigrate: [DEBUG] Loading the driver from the URI
  omigrate: [DEBUG] Querying existing databases
  omigrate: [INFO] Database already exists
  omigrate: [INFO] Creating the migration table if not exists
  omigrate: [DEBUG] Loading the driver from the URI
  omigrate: [DEBUG] Querying all versions
  omigrate: [INFO] Applying up migration 33
  omigrate: [DEBUG] Inserting version 33 in migration table
  omigrate: [INFO] Applying up migration 44
  omigrate: [DEBUG] Inserting version 44 in migration table

Verify the tables in the sqlite3 database
  $ sqlite3 test.db ".tables"
  pets               schema_migrations

Check that we have everything in  the sqlite3 schema table
  $ omigrate ls -d "sqlite3:///$PWD/test.db" -s ./sqlite3 -vv
  omigrate: [DEBUG] Loading the driver from the URI
  omigrate: [DEBUG] Querying all versions
  create_table - applied
  alter_table - applied

Drop everything in the sqlite3 database
  $ omigrate down -d "sqlite3://$PWD/test.db" -s ./sqlite3 -v
  omigrate: [INFO] Applying down migration 44
  omigrate: [INFO] Applying down migration 33

Ensure only the schema_migration remain
  $ sqlite3 test.db ".tables"
  schema_migrations
