BEGIN;
DROP INDEX IF EXISTS user_projects_dd8dfss;
DROP TABLE IF EXISTS user_projects;
DROP INDEX IF EXISTS addresses_dfd7fs7ss;
DROP TABLE IF EXISTS addresses;
DROP INDEX IF EXISTS posts_df8sdd;
DROP TABLE IF EXISTS posts;

DROP INDEX IF EXISTS users_4ijlkjdf;
DROP TABLE IF EXISTS users;
DROP INDEX IF EXISTS users_different_defaults_kljl3kj;
DROP TABLE IF EXISTS users_different_defaults;
DROP INDEX IF EXISTS users_4asdf;
DROP TABLE IF EXISTS users_large_defaults;
DROP INDEX IF EXISTS projects_88fsssfsf;
DROP TABLE IF EXISTS projects;

DROP INDEX IF EXISTS users_json_f2f2f9sd;
DROP TABLE IF EXISTS users_json;

DROP INDEX IF EXISTS things_f4f74pppa;
DROP TABLE IF EXISTS things;

CREATE TABLE users(
  id INTEGER NOT NULL,
  name character varying NOT NULL,
  smallnum smallint,
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

CREATE TABLE posts(
  id INTEGER NOT NULL,
  user_id INTEGER references users(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE posts_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;
ALTER TABLE ONLY posts ADD CONSTRAINT posts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);
CREATE UNIQUE INDEX posts_df8sdd ON posts (id);

CREATE TABLE addresses(
  id INTEGER NOT NULL,
  user_id INTEGER references users(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE addresses_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE addresses_id_seq OWNED BY addresses.id;
ALTER TABLE ONLY addresses ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);
ALTER TABLE ONLY addresses ALTER COLUMN id SET DEFAULT nextval('addresses_id_seq'::regclass);
CREATE UNIQUE INDEX addresses_dfd7fs7ss ON addresses (id);

CREATE TABLE projects(
  id INTEGER NOT NULL,
  name VARCHAR(255),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE projects_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;
ALTER TABLE ONLY projects ADD CONSTRAINT projects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);
CREATE UNIQUE INDEX projects_88fsssfsf ON projects (id);


CREATE TABLE user_projects(
  id INTEGER NOT NULL,
  user_id INTEGER,
  project_id INTEGER references projects(id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE user_projects_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE user_projects_id_seq OWNED BY user_projects.id;
ALTER TABLE ONLY user_projects ADD CONSTRAINT user_projects_pkey PRIMARY KEY (id);
ALTER TABLE ONLY user_projects ALTER COLUMN id SET DEFAULT nextval('user_projects_id_seq'::regclass);
CREATE UNIQUE INDEX user_projects_dd8dfss ON user_projects (id);

CREATE TABLE users_json(
  id INTEGER NOT NULL,
  settings jsonb,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE users_json_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE users_json_id_seq OWNED BY users_json.id;
ALTER TABLE ONLY users_json ADD CONSTRAINT users_json_pkey PRIMARY KEY (id);
ALTER TABLE ONLY users_json ALTER COLUMN id SET DEFAULT nextval('users_json_id_seq'::regclass);
CREATE UNIQUE INDEX users_json_f2f2f9sd on users_json (id);

CREATE TABLE things(
  id INTEGER NOT NULL,
  user_different_defaults_id INTEGER references users_different_defaults(user_id),
  created_at timestamp without time zone,
  updated_at timestamp without time zone
);

CREATE SEQUENCE things_id_seq
  START WITH 1121
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE things_id_seq OWNED BY things.id;
ALTER TABLE ONLY things ADD CONSTRAINT things_pkey PRIMARY KEY (id);
ALTER TABLE ONLY things ALTER COLUMN id SET DEFAULT nextval('things_id_seq'::regclass);
CREATE UNIQUE INDEX things_f4f74pppa on things (id);

COMMIT;
