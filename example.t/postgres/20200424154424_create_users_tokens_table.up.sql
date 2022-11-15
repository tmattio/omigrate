CREATE TABLE "public"."users_tokens"(
  "id" serial NOT NULL,
  "user_id" int NOT NULL,
  "token" bytea NOT NULL,
  "context" text NOT NULL,
  "sent_to" email,
  "created_at" timestamp(0) without time zone NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "users_tokens_user_id_fkey" FOREIGN KEY ("user_id")
    REFERENCES "public"."users" ("id") MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE CASCADE
);

CREATE UNIQUE INDEX "users_tokens_context_token_index"
  ON "public"."users_tokens" USING btree
  ("context", "token");

CREATE INDEX "users_tokens_user_id_index"
  ON "public"."users_tokens" USING btree
  ("user_id");
