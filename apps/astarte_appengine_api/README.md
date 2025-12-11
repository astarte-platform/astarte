# ⚙️ App Engine (ae)

AppEngine is Astarte's main API endpoint for end users. AppEngine exposes a
RESTful API to retrieve and send data from/to devices, according to their
interfaces. Every direct device interaction can be done from here. It also
exposes Channels, a WebSocket-based solution for listening to device events in
real-time with Triggers' same mechanism and semantics.

When running a full astarte instance (e.g., trough [astarte in 5 minutes](https://docs.astarte-platform.org/astarte/latest/010-astarte_in_5_minutes.html))
REST API documentation can be viewed at the `/swagger` endpoint of appengine
(example: <http://api.astarte.localhost/appengine/swagger/>).

<img src="appengine_astarte_overview.svg" align="center" />

## 🔧 Build

to build ae you can follow the usual elixir flow

```shell
mix deps.get
mix compile
```

to lint ae code and get some insights on pattern matching and typing you can
run dialyzer.

```shell
mix dialyzer
```

nb: all PRs have to be linter-approved, so running `mix dialyzer` before makeing
a pull request saves everyone some precious review time!

## 🧑‍🔬 Test

to test ae you need a running instance of rabbitmq and a cassandra-compatible
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
