DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS users_different_defaults;
DROP TABLE IF EXISTS users_large_defaults;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS user_projects;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS things;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS users_uuid_custom;
DROP TABLE IF EXISTS things_that_belong_to_user_uuid_custom;

CREATE TABLE users(
  id INTEGER NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  things integer,
  smallnum integer,
  stuff integer,
  nope float,
  yep bool,
  pageviews bigint,
  some_date DATETIME,
  created_at DATETIME,
  updated_at DATETIME,
  unique_field varchar(255) UNIQUE
);

CREATE UNIQUE INDEX users_4ijlkjdf ON users (id);

CREATE TABLE users_different_defaults(
  user_id INTEGER NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  xyz DATETIME
);

CREATE UNIQUE INDEX users_different_defaults_kljl3kj on users_different_defaults (user_id);

/* INTEGER can store big numbers, this is the only type that supports
   auto_increment ROWID*/
CREATE TABLE users_large_defaults(
  id INTEGER NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL
);

CREATE UNIQUE INDEX users_4asdf ON users_large_defaults (id);

CREATE TABLE posts(
  id INTEGER NOT NULL PRIMARY KEY,
  user_id INTEGER references users(id),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX posts_df8sdd ON posts (id);

CREATE TABLE addresses(
  id INTEGER NOT NULL PRIMARY KEY,
  user_id INTEGER references users(id),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX addresses_dfd7fs7ss ON addresses (id);

CREATE TABLE projects(
  id INTEGER NOT NULL PRIMARY KEY,
  name VARCHAR(255),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX projects_88fsssfsf ON projects (id);

CREATE TABLE user_projects(
  user_id INTEGER references users(id),
  project_id INTEGER references projects(id)
);

CREATE TABLE things(
  id INTEGER NOT NULL PRIMARY KEY,
  user_different_defaults_id INTEGER references users_different_defaults(id),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX things_9sd09df ON things (id);

CREATE TABLE users_uuid(
  uuid VARCHAR(255) PRIMARY KEY NOT NULL,
  name VARCHAR(255),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX users_uuid_93vabznv8 ON users_uuid (uuid);

CREATE TABLE vehicles(
  id INTEGER NOT NULL PRIMARY KEY,
  state_string VARCHAR(255) NOT NULL,
  vehicle_type INTEGER NOT NULL,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX vehicles_f4f74ccccc on vehicles (id);

CREATE TABLE users_uuid_custom(
  id VARCHAR(36) NOT NULL PRIMARY KEY,
  name VARCHAR(255),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX users_uuid_custom_cccccchh on users_uuid_custom(id);

CREATE TABLE things_that_belong_to_user_uuid_custom(
  id VARCHAR(36) NOT NULL PRIMARY KEY,
  users_uuid_custom_id VARCHAR(36) NOT NULL REFERENCES users_uuid_custom(id),
  name VARCHAR(255),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX things_that_belong_to_user_uuid_custom_kugvegdgbvu on things_that_belong_to_user_uuid_custom(id);

CREATE TABLE things_without_fields(
  id INTEGER NOT NULL PRIMARY KEY,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX things_without_fields_cccccchh on things_without_fields (id);
