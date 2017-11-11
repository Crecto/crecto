BEGIN;
DROP TABLE IF EXISTS user_projects;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS users_different_defaults;
DROP INDEX IF EXISTS users_4asdf;
DROP TABLE IF EXISTS users_large_defaults;
DROP TABLE IF EXISTS users_arrays;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS users_json;
DROP TABLE IF EXISTS things;
DROP TABLE IF EXISTS users_uuid;
DROP TABLE IF EXISTS vehicles;

CREATE TABLE users(
  id BIGSERIAL PRIMARY KEY,
  name character varying NOT NULL,
  smallnum smallint,
  things integer,
  stuff integer,
  nope float,
  yep bool,
  pageviews bigint,
  some_date timestamp without time zone,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  unique_field character varying UNIQUE
);

CREATE TABLE users_different_defaults(
  user_id BIGSERIAL PRIMARY KEY,
  name character varying NOT NULL,
  xyz timestamp without time zone
);

CREATE TABLE users_large_defaults(
  id BIGINT PRIMARY KEY,
  name character varying NOT NULL
);

CREATE SEQUENCE users_large_defaults_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE users_large_defaults_id_seq OWNED BY users_large_defaults.id;
ALTER TABLE ONLY users_large_defaults ALTER COLUMN id SET DEFAULT nextval('users_large_defaults_id_seq'::regclass);
CREATE UNIQUE INDEX users_4asdf ON users_large_defaults (id);

CREATE TABLE users_arrays(
  id BIGSERIAL PRIMARY KEY,
  string_array varchar[],
  int_array INTEGER[],
  float_array float[],
  bool_array bool[],
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE posts(
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER references users(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE addresses(
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER references users(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE projects(
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);


CREATE TABLE user_projects(
  user_id INTEGER,
  project_id INTEGER references projects(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE users_json(
  id BIGSERIAL PRIMARY KEY,
  settings jsonb,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE things(
  id BIGSERIAL PRIMARY KEY,
  user_different_defaults_id INTEGER references users_different_defaults(user_id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE TABLE users_uuid(
  uuid character varying NOT NULL,
  name character varying,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);


CREATE TABLE vehicles(
  id BIGSERIAL PRIMARY KEY,
  state_string character varying NOT NULL,
  vehicle_type INTEGER NOT NULL,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

COMMIT;
