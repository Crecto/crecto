FROM crystallang/crystal:0.27.0 AS base
MAINTAINER Nick Franken <shnick@gmail.com>

RUN apt-get -q update && \
  apt-get -qy install --no-install-recommends build-essential git wget libssl-dev libxml2-dev libyaml-0-2 libreadline-dev netcat libsqlite3-dev

WORKDIR /crecto
COPY shard.yml /crecto/
RUN shards install
ENTRYPOINT ["/crecto/bin/specs"]

FROM base AS sqlite
RUN apt-get -q update && apt-get -qy install --no-install-recommends sqlite3
COPY bin /crecto/bin
COPY spec /crecto/spec
COPY src /crecto/src
COPY ./spec/migrations/sqlite3_migrations.sql /crecto/spec/migrations/
CMD ["sqlite"]

FROM base AS postgres
RUN apt-get -q update && apt-get -qy install --no-install-recommends libpq-dev postgresql-client
COPY bin /crecto/bin
COPY spec /crecto/spec
COPY src /crecto/src
COPY ./spec/migrations/pg_migrations.sql /crecto/spec/migrations/
CMD ["postgres"]

FROM base AS mysql
RUN apt-get -q update && apt-get -qy install --no-install-recommends mysql-client libmysqlclient-dev 
COPY bin /crecto/bin
COPY spec /crecto/spec
COPY src /crecto/src
COPY ./spec/migrations/mysql_migrations.sql /crecto/spec/migrations/
CMD ["mysql"]
