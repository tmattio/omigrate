CREATE TABLE pets (
  name string NOT NULL DEFAULT "dog"
);

CREATE TABLE users (
    name string NOT NULL DEFAULT "anonymous"
);

ALTER TABLE users ADD developer bool NOT NULL DEFAULT false;
