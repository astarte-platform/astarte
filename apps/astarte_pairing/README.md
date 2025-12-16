# 🫂 Astarte Pairing (pg)

Pairing takes care of Device Authentication and Authorization. It interacts with
Astarte's CA and orchestrates the way devices connect and interact with
Transports. It also handles Device Registration. Agent, Device and Pairing
interaction is described in detail [in the astarte documentation](https://docs.astarte-platform.org/astarte/snapshot/050-pairing_mechanism.html).

## 🔧 Build

to build pg you can follow the usual elixir flow

```shell
mix deps.get
mix compile
```

to lint pg code and get some insights on pattern matching and typing you can
run dialyzer.

```shell
mix dialyzer
```

nb: all PRs have to be linter-approved, so running `mix dialyzer` before making
a pull request saves everyone some precious review time!

## 🧑‍🔬 Test

to test pg you need a running instance of CFSSL and a cassandra-compatible
database, (we suggest scylla)

```shell
docker run --rm -d -p 9042:9042 --name scylla scylladb/scylla
docker run --rn -d --net=host -p 8080/tcp ispirata/docker-alpine-cfssl-autotest:astarte
```

by default `CASSANDRA_NODES` and `CFSSL_API_URL` environment variables map to localhost, so that

```shell
mix test
```

just works. In more complex scenarios you might need to tell to astarte where
these resources are located.

```shell
CASSANDRA_NODES=localhost CFSSL_API_URL=http://localhost:8080 mix test
```
