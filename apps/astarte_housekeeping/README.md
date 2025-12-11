# 🧹 Astarte Housekeeping (hk)

Housekeeping is the equivalent of a superadmin API. It is usually not accessible
to the end user but rather to Astarte's administrator who, in most cases, might
deny overall outside access. It allows to manage and create Realms, and perform
cluster-wide maintenance actions.

## 🔧 Build

to build hk you can follow the usual elixir flow

```shell
mix deps.get
mix compile
```

to lint hk code and get some insights on pattern matching and typing you can
run dialyzer.

```shell
mix dialyzer
```

nb: all PRs have to be linter-approved, so running `mix dialyzer` before makeing
a pull request saves everyone some precious review time!

## 🧑‍🔬 Test

to test hk you need a running instance of rabbitmq and a cassandra-compatible
database, (we suggest scylla)

```shell
docker run --rm -d -p 9042:9042 --name scylla scylladb/scylla
```

by default `CASSANDRA_NODES` environment variable map to `localhost`, so that

```shell
mix test
```

just works. In more complex scenarios you might need to tell to astarte where
these resources are located.

```shell
CASSANDRA_NODES=localhost mix test
```
