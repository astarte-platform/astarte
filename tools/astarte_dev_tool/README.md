# AstarteDevTool

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `astarte_dev_tool` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:astarte_dev_tool, "~> 0.1.0"}
  ]
end
```

## Usage

Currently, the functionalities of `astarte_dev_tool` are stateless and based on the `mix task` mechanism.

### Starting the System

To start `docker compose` in development mode, use:

```bash
mix astarte_dev_tool.system.up --path <astarte-path>
```

where the following options are:

* `-p` `--path` - (required) working Astarte project directory

### Stopping the System

To stop `docker compose` in development mode, use:

```bash
mix astarte_dev_tool.system.down --path <astarte-path>
```

where the following options are:

* `-p` `--path` - (required) working Astarte project directory 

### Watching for Changes

To enable watch mode for hot-code-reloading, use:

```bash
mix astarte_dev_tool.system.watch --path <astarte-path>
```

where the following options are:

* `-p` `--path` - (required) working Astarte project directory

This command will start the system in watch mode and keep running in the foreground, allowing for real-time code reloading during development.

### Accessing the Dashboard

To open an authenticated Dashboard session on your web browser:

```bash
mix astarte_dev_tool.dashboard.open --path 
```

where the following options are:

* `-r` `--realm-name` - (required) The name of the Astarte realm.
* `-u` `--dashboard-url` - (required) The URL of the Astarte Dashboard
* `-k` `--realm-private-key` - (required if --auth-token is not provided) The path of the private key for the Astarte
  realm.
* `-t` `--auth-token` - (required if --realm-private-key is not provided) The auth token to use. If specified, it takes
  precedence over the --realm-private-key option.

---

### Example

1. Start the system: `mix astarte_dev_tool.system.up --path ../../../astarte`
2. Enable watch mode: `mix astarte_dev_tool.system.watch --path ../../../astarte`
3. Open the Astarte Dashboard: `mix astarte_dev_tool.dashboard.open --realm-name test --dashboard-url http://dashboard.astarte.localhost --realm-private-key ../../../astarte/test_private.pem`
4. Stop the system: `mix astarte_dev_tool.system.down --path ../../../astarte`

These commands will help you manage the development environment for Astarte efficiently.

---

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/astarte_dev_tool>.
