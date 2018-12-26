FROM crystallang/crystal:0.27.0
MAINTAINER Nick Franken <shnick@gmail.com>

RUN apt-get -q update && \
  apt-get -qy install --no-install-recommends build-essential libpq-dev sqlite3 mysql-client  libsqlite3-dev libmysqlclient-dev libssl-dev git wget postgresql-client libxml2-dev libyaml-0-2 libreadline-dev netcat && \
  apt-get update && \
  apt-get -y autoremove && \
  apt-get -y clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/*

WORKDIR /crecto

ADD shard.yml shard.lock /crecto/

RUN shards install

ADD ./spec/migrations/sqlite3_migrations.sql ./spec/migrations/pg_migrations.sql ./spec/migrations/mysql_migrations.sql /crecto/spec/migrations/
