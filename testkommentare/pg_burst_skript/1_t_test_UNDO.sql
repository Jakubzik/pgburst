CREATE TABLE "public"."t_test" (
    "id" integer NOT NULL,
    "comment" "text"
);
ALTER TABLE "public"."t_test" OWNER TO "heiko";

ALTER TABLE ONLY "public"."t_test" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."t_test_id_seq"'::"regclass")