BEGIN;

DROP INDEX IF EXISTS users_4ijlkjdf;
DROP TABLE IF EXISTS users;
DROP INDEX IF EXISTS users_different_defaults_kljl3kj;
DROP TABLE IF EXISTS users_different_defaults;
DROP INDEX IF EXISTS users_4asdf;
DROP TABLE IF EXISTS users_large_defaults;

CREATE TABLE users(
  id INTEGER NOT NULL,
  name character varying NOT NULL,
  things integer,
  stuff integer,
  nope float,
  yep bool,
  pageviews bigint,
  some_date timestamp without time zone,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE users_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE users_id_seq OWNED BY users.id;
ALTER TABLE ONLY users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);
CREATE UNIQUE INDEX users_4ijlkjdf ON users (id);

CREATE TABLE users_different_defaults(
  user_id INTEGER NOT NULL,
  name character varying NOT NULL,
  xyz timestamp without time zone
);

CREATE SEQUENCE users_different_defaults_user_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE users_different_defaults_user_id_seq OWNED BY users_different_defaults.user_id;
ALTER TABLE ONLY users_different_defaults ADD CONSTRAINT users_different_defaults_pkey PRIMARY KEY (user_id);
ALTER TABLE ONLY users_different_defaults ALTER COLUMN user_id SET DEFAULT nextval('users_different_defaults_user_id_seq'::regclass);
CREATE UNIQUE INDEX users_different_defaults_kljl3kj on users_different_defaults (user_id);

CREATE TABLE users_large_defaults(
  id BIGINT NOT NULL,
  name character varying NOT NULL
);

CREATE SEQUENCE users_large_defaults_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE users_large_defaults_id_seq OWNED BY users_large_defaults.id;
ALTER TABLE ONLY users_large_defaults ADD CONSTRAINT users_large_defaults_pkey PRIMARY KEY (id);
ALTER TABLE ONLY users_large_defaults ALTER COLUMN id SET DEFAULT nextval('users_large_defaults_id_seq'::regclass);
CREATE UNIQUE INDEX users_4asdf ON users_large_defaults (id);

COMMIT;
