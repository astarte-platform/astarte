🧠 Data Updater Plant (dup)
===================================

Data Updater Plant is a replicable, scalable component which takes care of the
ingestion pipeline. It gathers data from devices and orchestrates data flow
amongst other components. It is, arguably, the most critical component of the
system and the most resource hungry - the way dup is deployed, replicated and
configured has a tremendous impact on Astarte's performances, especially when
dealing with massive data flows.

<img src="data_updater_astarte_overview.svg" align="center" />

## 🔧 Build

to build dup you can follow the usual elixir flow

``` shell
mix deps.get
mix compile
```

to lint dup code and get some insights on pattern matching and typing you can
run dialyzer.

``` shell
mix dialyzer
```

nb: all PRs have to be linter-approved, so running `mix dialyzer` before makeing
a pull request saves everyone some precious review time!

## 🧑‍🔬 Test

to test dup you need a running instance of rabbitmq and a cassandra-compatible
database, (we suggest scylla)

``` shell
docker run --rm -d -p 9042:9042 --name scylla scylladb/scylla
docker run --rm  -d -p 5672:5672 -p 15672:15672 --name rabbit rabbitmq:3.12.0-management
```

by default `RABBITMQ_HOST` and `CASSANDRA_NODES` environment variables map to
`localhost`, so that

``` shell
mix test
```

just works. In more complex scenarios you might need to tell to astarte where
these resources are located.

``` shell
RABBITMQ_HOST=localhost CASSANDRA_NODES=localhost mix test
```
