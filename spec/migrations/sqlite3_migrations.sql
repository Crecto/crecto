DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS users_different_defaults;
DROP TABLE IF EXISTS users_large_defaults;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS user_projects;
DROP TABLE IF EXISTS projects;

CREATE TABLE users(
  id INTEGER NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  things integer,
  stuff integer,
  nope float,
  yep bool,
  pageviews bigint,
  some_date DATETIME,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX users_4ijlkjdf ON users (id);

CREATE TABLE users_different_defaults(
  user_id INTEGER NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  xyz DATETIME
);

CREATE UNIQUE INDEX users_different_defaults_kljl3kj on users_different_defaults (user_id);

CREATE TABLE users_large_defaults(
  id BIGINT NOT NULL PRIMARY KEY,
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
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX projects_88fsssfsf ON projects (id);

CREATE TABLE user_projects(
  id INTEGER NOT NULL PRIMARY KEY,
  user_id INTEGER references users(id),
  project_id INTEGER references projects(id),
  created_at DATETIME,
  updated_at DATETIME
);

CREATE UNIQUE INDEX user_projects_dd8dfss ON user_projects (id);
