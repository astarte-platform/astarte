👑 Realm Management (rm)
========================

Realm Management is an administrator-like API for configuring a Realm. It is
mainly used to manage Interfaces and Triggers. It serves a [REST
API](priv/static/astarte_realm_management.yaml) that allows administration
panels and applications to manage a certain realm, allowing CRUD operations on
interfaces, triggers and allows device deletion and realm configuration.

## 🔧 Build

to build rm you can follow the usual elixir flow

``` shell
mix deps.get
mix compile
```

to lint rm code and get some insights on pattern matching and typing you can
run dialyzer.

``` shell
mix dialyzer
```

nb: all PRs have to be linter-approved, so running `mix dialyzer` before makeing
a pull request saves everyone some precious review time!

## 🧑‍🔬 Test

to test rm you need a running instance of rabbitmq and a cassandra-compatible
database, (we suggest scylla)

``` shell
docker run --rm -d -p 9042:9042 --name scylla scylladb/scylla
```

by default `CASSANDRA_NODES` environment variable map to `localhost`, so that

``` shell
mix test
```

just works. In more complex scenarios you might need to tell to astarte where
these resources are located.

``` shell
CASSANDRA_NODES=localhost mix test
```
