CREATE EXTENSION IF NOT EXISTS citext;

-- Since RFC 5322 is too complex for mere humans to comprehend, using HTML5 email spec.
-- "This requirement is a willful violation of RFC 5322, which defines a syntax for e-mail addresses that is simultaneously too strict (before the "@" character), too vague (after the "@" character), and too lax (allowing comments, whitespace characters, and quoted strings in manners unfamiliar to most users) to be of practical use here."
CREATE DOMAIN email AS citext CHECK (
  value ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
);

CREATE DOMAIN username AS citext CHECK (
  value ~ '^[a-zA-Z0-9_-]*$'
);

COMMENT ON DOMAIN email IS 'Email addresses must valid.';

CREATE TABLE "public"."users"(
  "id" serial NOT NULL,
  "username" username UNIQUE NOT NULL CONSTRAINT "username_length" CHECK (char_length("username") <= 60),
  "email" email UNIQUE NOT NULL CONSTRAINT "email_length" CHECK (char_length("email") <= 255),
  "hashed_password" text NOT NULL,
  "confirmed_at" timestamp(0) without time zone,
  "created_at" timestamp(0) without time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp(0) without time zone NOT NULL DEFAULT now(),
  PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_email_index"
  ON "public"."users" USING btree
  ("email");

CREATE UNIQUE INDEX "users_username_index"
  ON "public"."users" USING btree
  ("username");

CREATE OR REPLACE FUNCTION "public"."set_current_timestamp_updated_at"()
RETURNS TRIGGER AS $$
DECLARE
  _new record;
BEGIN
  _new := NEW;
  _new."updated_at" = now();
  RETURN _new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "set_public_users_updated_at"
BEFORE UPDATE ON "public"."users"
FOR EACH ROW
EXECUTE PROCEDURE "public"."set_current_timestamp_updated_at"();

COMMENT ON TRIGGER "set_public_users_updated_at" ON "public"."users" 
IS 'trigger to set value of column "updated_at" to current timestamp on row update';

COMMENT ON TABLE "public"."users" IS 'A user in the system.';

COMMENT ON COLUMN "public"."users"."id" IS 'Unique identifier of the user.';

COMMENT ON COLUMN "public"."users"."email" IS 'Email address of the user.';

COMMENT ON COLUMN "public"."users"."created_at" IS 'Creation time of the user.';
