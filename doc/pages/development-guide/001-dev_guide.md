# Development Guide

Welcome to Astarte! To learn more about contributing to the [Astarte project](https://www.github.com/astarte-platform/astarte), check out the [Contributor's Guide](https://github.com/astarte-platform/astarte/blob/master/CONTRIBUTING.md).

This guide is focused on writing and testing changes to Astarte. It assumes basic knowledge in the following areas:

- You have read the [contributing guidelines](https://github.com/astarte-platform/astarte/blob/master/CONTRIBUTING.md) for the project
- You are familiar with basic Astarte concepts such as Realms, Interfaces, Devices and Triggers. If you are not, you can learn more on the [documentation](001-intro_architecture.md)!
- You have already run at least once [Astarte in 5 minutes](010-astarte_in_5_minutes.md)
- If you plan to work on the code, you have some knowledge of Elixir and Docker

### Platforms

Currently, the development of [Astarte project](https://www.github.com/astarte-platform/astarte) is tested on the following platforms:

- Ubuntu linux >= 20.04, amd64/arm64
- Debian linux >= bullseye, amd64/arm64
- macOS amd64/arm64, via Microsoft VSCode devcontainer

## Where to start?

To make your contribution, let's first identify where to do it.

### Code

In general, you will probably touch one of the Astarte components.
Astarte is made up of a number of different microservices: [here](020-components.html) you can find a quick summary of each.

Moreover, components that expose an API (Housekeeping, Pairing, Realm Management) are split in an API service and a backend one. All of those are located in the [main Astarte repository](https://www.github.com/astarte-platform/astarte) on Github, in the `apps` directory.

Finally, Astarte is backed by three libraries:

- [Astarte Core](https://github.com/astarte-platform/astarte_core): contains definitions common to the application, e.g. Realm name, Device ID validity, Interface definitions etc.
- [Astarte RPC](https://github.com/astarte-platform/astarte_rpc): contains all the Protobufs and code used in the internal RPC mechanism. In most cases, RPCs are between an API component and the related backend.
- [Astarte Data Access](https://github.com/astarte-platform/astarte_data_access): contains some interactions with the database that are common to all Astarte services, e.g. queries for interface values.

### Documentation

Documentation is automatically generated from files in the `doc/pages` subdirectory of the [main Astarte repository](https://www.github.com/astarte-platform/astarte) on Github.
It is written in Github-flavored markdown.

### Tooling

The main Astarte repo contains a number of tools that can be used everyday when interacting with Astarte. They are found in the `tools` directory subdirectory of the [main Astarte repository](https://www.github.com/astarte-platform/astarte) on Github:

- Astarte Device Fleet Simulator: create a fleet of virtual devices. Mainly used for load testing
- Astarte E2E: a tool that sends data from a virtual device and checks the resulting value in Astarte using triggers. Mainly used for monitoring
- Astarte Import and Astarte Export: used to load/export data into/from Astarte
- Astarte Dev Tool: development helper, facilitating the up & running of the platform in development mode (see [astarte_dev_tool](#astarte_dev_tool))

## Environment

There are two possible alternatives for development, depending on whether you want to use a complete setup on the development host or prefer to use devcontainers.
The choice also falls on whether you want to [work on a single component](#testing-a-single-component) or prefer to start up the entire Astarte platform.

### Devcontainers (preferred on macOs, requires Microsoft VSCode as IDE)

The development system only requires _docker_ and _docker compose_ to be installed. macOS users normally prefer to use _Docker Desktop_, in which case _docker compose_ is automatically installed.
The development containers will already have the necessary add-ons to optimise the work.

> [!NOTE]
> When using dev containers, it is only possible to work on Astarte  [apps](https://www.github.com/astarte-platform/astarte), with the main requirement that all the Astarte containers must  be started.
> If you want to work on the other tools or libraries (e.g. [Astarte Core](https://github.com/astarte-platform/astarte_core)), you must use another set-up method.

### Host with Elixir installed

In order to install and manage Elixir (and Erlang), we recommend using either the [asdf](https://asdf-vm.com/) runtime version manager or the [nix](https://nixos.org/) package manager.

#### Using asdf

From inside the main Astarte directory, install the Elixir and Erlang asdf plugins
```bash
asdf plugin add erlang
asdf plugin add elixir
```

Then install Elang/OTP and Elixir with
```bash
asdf install
```

#### Using nix

From inside the main Astarte directory, just run
- `nix develop`, if you are using flakes
- `nix-shell`, if not

## Development on the entire platform

The easiest way to develop on the whole platform is to start the project (and, thus, every astarte container) with _docker compose_ in "development" mode.
This way you can also enable the hot reloading mode with the 'watch' command of [astarte_dev_tool](https://www.github.com/astarte-platform/astarte) or directly with _docker compose_.

From inside the astarte_dev_tool directory, `mix build` to build the tool itself, followed by the commands to use it. Note that the root Astarte directory must be explicitly specified with `-p`:

- `mix astarte_dev_tool.system.up -p <path>`, starts the platform and all containers in "dev-mode".
- `mix astarte_dev_tool.system.watch -p <path>`, starts the "watcher", which allows hot-code reloading in case of code changes. The process is stopped and must be explicitly closed with `ENTER`.
- `mix astarte_dev_tool.system.down -p <path> [-v]`, to terminate the platform. The `-v` parameter will also delete the volumes of the respective containers.

### docker compose

From inside the Astarte directory:

- `docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build [-d]`, starts the platform and all containers in "dev-mode".
- `docker compose -f docker-compose.dev.yml -f docker-compose.dev.yml watch --no-up`, starts the watching. The process must be terminated explicitly with `Ctrl+C`.
- `docker compose -f docker-compose.dev.yml -f docker-compose.dev.yml down [-v]`, to terminate the platform. The `-v` parameter will also delete the volumes of the respective containers.

## Development on individual components

It is also possible not to start the entire platform, to do so enter the directory of the service you are interested in and run the appropriate mix command (varies from service to service).
Usually you don't want to do so, though.

### Can I use an Elixir REPL to help me during development?

Sure thing! However, usually Astarte services do need some context around them.
Refer to the following ["Testing a single component"](#testing-a-single-component) paragraph for dependencies, then you can start your application with an interactive shell by replacing `mix test` with `iex -S mix`

### Testing a single component

In general, you will have to bring up a RabbitMQ and a Scylla instance (not all services need both: API services will not need access to the database).
You can do so by running
```bash
docker run --rm -p 5672:5672 -p 15672:15672 rabbitmq:management
docker run --rm -p 9042:9042 scylladb/scylla
```

Then, you can run test in the component directory with
```bash
RABBITMQ_HOST=localhost CASSANDRA_NODES=localhost mix test --exclude wip
```

> [!NOTE]
> Some services are a bit special (for now!) and might need a little more setup for testing.
> - AppEngine API needs the AMQP exchange `astarte_events` to be declared:
> after having started RabbitMQ, run the following lines to declare it:
>  ```bash
>   docker exec $RABBITMQ_CONTAINER_NAME rabbitmqadmin declare exchange name=astarte_events type=direct
>  ```

> - Pairing needs a CFSSL instance available and exposed on port 8080: you can run
>  ```bash
>  docker run --net=host -p 8080/tcp ispirata/docker-alpine-cfssl-autotest:astarte
>  ```
> and then test using
>  ```bash
>  RABBITMQ_HOST=localhost CASSANDRA_NODES=localhost CFSSL_API_URL=http://localhost:8080 mix test --exclude wip
>  ```

## Ok, I made changes, what now?

Once you got your hands dirty, is time to test them.
You can test changes to a single component, or run E2E tests if more than one service is involved.

Remember that a contribution should always include tests for the new functionality or the fix.
We use the [ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html) framework for unit testing.
Work is under way to add property-based testing too!

### E2E testing

docker compose is the quick-and-dirty way to spin up a development instance of Astarte.
You can do so just by running `docker compose up -d` in the main Astarte directory.
You can rebuild the service you’re working on with `docker compose build $SERVICE_NAME`,
or edit the `docker-compose.yml` file to change the service image name.
The first time you're running Astarte, you will have to run
```bash
docker run -v $(pwd)/compose:/compose astarte/docker-compose-initializer:snapshot
```

in order to set up the Housekeeping keypair, the devices root CA and a certificate for the broker.

Then, you can use the following commands to manage Astarte services:
- `docker compose up -d` starts all containers in detached mode
- `docker compose down $SERVICE_NAME -v` stops and cleans the service you’re working on
- `docker compose up $SERVICE_NAME --build` rebuilds the service and restarts it. If you don’t need to tail logs, you may add `-d`

## Useful commands

Now, some commands you might find helpful to set up a realm:

- Create a realm keypair:
`astartectl utils gen-keypair $REALM_NAME`
- Create a Realm:
`astartectl housekeeping realms create $REALM_NAME -u http://api.astarte.localhost --housekeeping-key ./compose/astarte-keys/housekeeping_private.pem --realm-private-key $REALM_PRIVATE_KEY_FILE`
- Install a list of Interfaces in a Realm:
`astartectl realm-management interfaces sync $(find $INTERFACE_DIRECTORY -name '*.json') -u http://api.astarte.localhost -r $REALM_NAME -k $REALM_PRIVATE_KEY_FILE`
- Create a JWT wth claims on AppEngine, Pairing and RealmManagement APIs:
`astartectl utils gen-jwt all-realm-apis -k $REALM_PRIVATE_KEY_FILE`
- Start a virtual device:
`docker run --net="host" -e "DEVICE_ID=$(astartectl utils device-id generate-random)" -e "PAIRING_URL=http://api.astarte.localhost/pairing" -e "REALM=$REALM_NAME" -e "PAIRING_JWT=$(astartectl utils gen-jwt pairing -k $REALM_PRIVATE_KEY_FILE)" -e "IGNORE_SSL_ERRORS=true" astarte/astarte-stream-qt5-test:1.0.4`
    - In this case, two interfaces need to be already installed in your realm: `org.astarte-platform.genericsensors.Values` and `org.astarte-platform.genericcommands.ServerCommands`
    - You can find them in the `standard-interfaces` directory in the Astarte repo

### Sending data from Astarte to a device

Using `astartectl` you can send messages to a device. For example:

- Publish a (server-owned) datastream:
`astartectl appengine devices publish-datastream $DEVICE_ID $SERVER_OWNED_DATASTREAM_INTERFACE $PATH $VALUE -r $REALM_NAME -k $REALM_PRIVATE_KEY_FILE -u "http://api.astarte.localhost/"`
- Set a (server-owned) property:
`astartectl appengine devices set-property $DEVICE_ID $SERVER_OWNED_PROPERTY_INTERFACE $PATH $VALUE -r $REALM_NAME -k $REALM_PRIVATE_KEY_FILE -u "http://api.astarte.localhost/"`

## Virtual devices

If you want to have more flexibility with a virtual device, you can use an SDK (https://docs.astarte-platform.org/device-sdks/index.html).

To register a device, use the Astarte Dashboard at `http://dashboard.astarte.localhost/` and create a device.
Save the Device ID and the Credentials Secret for the device, and use them for connecting to Astarte.

### Example: using the Elixir SDK

Assuming you have a valid Device ID and the related Credentials Secret, you can use the [Astarte Device Elixir SDK](https://github.com/astarte-platform/astarte-device-sdk-elixir) to connect a virtual device.

Clone the project, move inside the directory and start a iEx shell:

```bash
git clone https://github.com/astarte-platform/astarte-device-sdk-elixir.git
cd astarte-device-sdk-elixir
iex -S mix
```

Now you can use the following commands to connect to Astarte:

```elixir
# Options to configure the device. <THESE> are placeholders for actual values.
opts = [pairing_url: "http://api.astarte.localhost/pairing", realm: "<YOUR_REALM>", device_id: "<YOUR_DEVICE_ID>", interface_provider: "<YOUR_INTERFACES_DIRECTORY>", credentials_secret: "<YOUR_CREDENTIALS_SECRET>", ignore_ssl_errors: true]

# Start the virtual device
{:ok, pid} = Astarte.Device.start_link(opts)

# Send a (device-owned) datastream
Astarte.Device.send_datastream(pid, "<A_DEVICE_OWNED_DATASTREAM_INTERFACE>", "<A_PATH>", <A_VALUE>)

# Set a (device-owned) property
Astarte.Device.set_property(pid, "<A_DEVICE_OWNED_PROPERTY_INTERFACE>", "<A_PATH>", <A_VALUE>)
```
