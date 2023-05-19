# Astarte in 5 minutes

**This documentation page describes a development version, for production systems please use the [stable version](https://docs.astarte-platform.org/latest) instead.**

This tutorial will guide you through bringing up your Astarte instance, creating a realm and streaming your first data from a device simulator (or a real device) before your cup of tea is ready.

## Before you begin

First of all, please keep in mind that **this setup is not meant to be used in production**: by default, no persistence is involved, the installation does not have any recovery mechanism, and you will have to restart services manually in case something goes awry. This guide is great if you want to take Astarte for a spin, or if you want to use an isolated instance for development.

You will need a machine with at least 4GB of RAM, a recent 64-bit operating system with [Docker](https://www.docker.com/), [Docker Compose](https://docs.docker.com/compose/install/) and [astartectl](https://github.com/astarte-platform/astartectl) installed. If you don't have `astartectl` installed on your machine yet, you should install it by following the instructions in [astartectl's README](https://github.com/astarte-platform/astartectl#installation)

Also, on the machine(s) or device(s) you will use as a client, you will need either Docker, or a [Qt5](https://www.qt.io/) installation with development components if you wish to build and run components locally.

Due to ScyllaDB requirements, if you're working on a Linux machine you should make sure that `aio-max-nr` is at least `1048576`:

```sh
cat /proc/sys/fs/aio-max-nr
1048576
```

If it's less than that, you'll need to edit your `/etc/sysctl.conf` file

```
fs.aio-max-nr = 1048576
```

and to persist this configuration

```sh
sudo sysctl -p
```

## Checking prerequistes

Docker version >= 19 is recommended:

```sh
$ docker -v
Docker version 19.03.8
```

Docker compose version >= 1.17 is recommended:

```sh
$ docker-compose -v
docker compose version 1.17.1, build unknown
```

astartectl 1.0.x is recommended:

```sh
$ astartectl version
astartectl 1.1.0-dev
```

This procedure has been tested on several systems, and is validated and maintained against
Ubuntu 18.04 and macOS 10.15 Catalina, but any other modern operating system should work.

## Install Astarte

To get our Astarte instance running as fast as possible, we will install Astarte's standalone distribution. It includes a tunable Docker Compose which brings up Astarte and every companion service needed for it to work. To do so, simply clone Astarte's main repository and use its scripts to bring it up:

```sh
$ git clone https://github.com/astarte-platform/astarte.git && cd astarte
$ docker run -v $(pwd)/compose:/compose astarte/docker-compose-initializer:1.1.0-alpha.0
$ docker-compose pull
$ docker-compose up -d
```

`docker-compose-initializer` will generate a root CA for devices, a key pair for Housekeeping, and a self-signed certificate for the broker (note: this is a *really* bad idea in production). You can tune the compose file further to use legitimate certificates and custom keys, but this is out of the scope of this tutorial.

Compose might take some time to bring everything up, but usually within a minute from the containers creation Astarte will be ready. Compose will forward the following ports to your machine:

* `4000`: Realm Management API
* `4001`: Housekeeping API
* `4002`: AppEngine API
* `4003`: Pairing API
* `4040`: Dashboard
* `8883`: MQTTS
* `1885`: MQTT with Proxy Protocol for SSL termination (won't be used)
* `80`: Let's Encrypt verification (won't be used)

This example won't use Let's Encrypt with VerneMQ - in case binding to port 80 is a problem to you, you can comment it out in `docker-compose.yml` without affecting any functionality.

To check everything went fine, use `docker ps` to verify relevant containers are up: Astarte itself, VerneMQ, PostgreSQL (used by CFSSL), CFSSL, RabbitMQ and ScyllaDB should be now running on your system. If any of them isn't up and running, `docker ps -a` should show it stopped or failed. In those cases, it is advised to issue `docker-compose up -d` again to fix potential temporary failures.

## Create a Realm

Now that we have our instance up and running, we can start setting up a Realm for our device. We'll call our Realm `test`. Given we have no SSO or Authentication mechanism set up, we're just going to generate a public key to sign our JWTs with. You can create one with `astartectl`:

```sh
$ astartectl utils gen-keypair test
```

Also, we will need a JWT token to authenticate against Housekeeping. `generate-compose-files.sh` created a keypair automatically, which is in `compose/astarte-keys/housekeeping_{private,public}.pem`. To perform all of our Astarte interactions, we will use `astartectl`.

Use `astartectl` to create a new Realm:

```sh
$ astartectl housekeeping realms create test --housekeeping-url http://localhost:4001/ --realm-public-key test_public.pem -k compose/astarte-keys/housekeeping_private.pem
```

This creates a `test` realm, which should be ready to be used almost immediately. To ensure your realm is available and ready, check if it exists in Astarte by issuing:

```sh
$ astartectl housekeeping realms ls --housekeeping-url http://localhost:4001/ -k compose/astarte-keys/housekeeping_private.pem
```

## Install an interface

We will use [Astarte's Qt5 Stream Generator](https://github.com/astarte-platform/stream-qt5-test) to feed data into Astarte. However before starting, we will have to install `org.astarte-platform.genericsensors.Values` interface into our new realm. To do that, we can use `astartectl` again:

```sh
$ astartectl realm-management interfaces sync standard-interfaces/org.astarte-platform.genericsensors.Values.json standard-interfaces/org.astarte-platform.genericcommands.ServerCommands.json --realm-management-url http://localhost:4000/ -r test -k test_private.pem -y
```

Now `org.astarte-platform.genericsensors.Values` should show up among our available interfaces:

```sh
$ astartectl realm-management interfaces ls --realm-management-url http://localhost:4000/ -r test -k test_private.pem
```

Our Astarte instance is now ready for our devices.

## Install a trigger

We will also test Astarte's push capabilities with a trigger. This will send a POST to a URL of our choice every time the value generated by `stream_test` is above 0.6.

Due to how triggers work, it is fundamental to install the trigger before a device connects. Doing otherwise will cause the trigger to kick in at a later time, and as such no events will be streamed for a while.

Replace `$TRIGGER_TARGET_URL` with your target URL in the example below, you can use a Postbin service like [Mailgun Postbin](http://bin.mailgun.net) to generate a URL and see the POST requests. The resulting trigger would be:

```json
{
  "name": "my_trigger",
  "action": {
    "http_url": "$TRIGGER_TARGET_URL",
    "http_method": "post"
  },
  "simple_triggers": [
    {
      "type": "data_trigger",
      "on": "incoming_data",
      "interface_name": "org.astarte-platform.genericsensors.Values",
      "interface_major": 1,
      "match_path": "/streamTest/value",
      "value_match_operator": ">",
      "known_value": 0.6
    }
  ]
}
```

Replace `$TRIGGER_TARGET_URL` with the URL your Trigger will target. Assuming you saved this as `my_trigger.json`, you can now install it through `astartectl`:

```sh
$ astartectl realm-management triggers install my_trigger.json --realm-management-url http://localhost:4000/ -r test -k test_private.pem
```

You can now check that your trigger is correctly installed:

```sh
$ astartectl realm-management triggers ls --realm-management-url http://localhost:4000/ -r test -k test_private.pem
```

## Stream data

If you already have an Astarte compliant device, you can configure it and connect it straight away,
and it will just work with your new installation - provided you skip SSL checks on the broker's
certificate. If you don't, you can use Astarte's `stream-qt5-test` to emulate an Astarte device and
generate a `datastream`. You can do this either on the same machine where you are running Astarte,
or from another machine or device on the same network.

### Using a container for stream-qt5-test

Astarte's `stream-qt5-test` can be pulled from Docker Hub with:

```sh
$ docker pull astarte/astarte-stream-qt5-test:v1.1.0-alpha.0
```

Its most basic invocation (from your `astarte` repository tree) is:

```sh
$ docker run --net="host" -e "DEVICE_ID=$(astartectl utils device-id generate-random)" -e "PAIRING_HOST=http://localhost:4003" -e "REALM=test" -e "AGENT_KEY=$(astartectl utils gen-jwt pairing -k test_private.pem)" -e "IGNORE_SSL_ERRORS=true" astarte/astarte-stream-qt5-test:v1.1.0-alpha.0
```

This will generate a random datastream from a brand new, random Device ID. You can tweak those parameters to whatever suits you better by having a look at the Dockerfile. You can spawn any number of instances you like, or you can have the same Device ID send longer streams of data by saving the container's persistency through a Docker Volume. If you wish to do so, simply add `-v /persistency:<your persistency path>` to your `docker run` invocation.

Refer to `stream-qt5-test` [README](https://github.com/astarte-platform/stream-qt5-test/blob/release-1.1/README.md) for more details on which variables can be passed to the container.

Also, please note that the `--net="host"` parameter is required to make `localhost` work. If this is not desirable, you can change `PAIRING_HOST` to an host reachable from within the container network. Obviously, that parameter isn't required if you're running the container on a different machine and `PAIRING_HOST` is pointing to a different URL.

## Grab your tea

Congratulations! Your devices or fake devices are now communicating with Astarte, and your tea should be ready by now. You can check if everything is working out by invoking AppEngine APIs to get some values. In case you are using `stream-qt5-test`, you can get the last sent value with `astartectl`:

```sh
$ astartectl appengine devices get-samples <your device id> org.astarte-platform.genericsensors.Values /streamTest/value --count 1 --appengine-url http://localhost:4002 -r test -k test_private.pem
```

If you get a meaningful value, congratulations - you have a working Astarte installation with your first `datastream` coming in!

Moreover, Astarte's Docker Compose also installs [Astarte Dashboard](https://github.com/astarte-platform/astarte-dashboard), from which you can manage your Realms and install Triggers, Interfaces and more from a Web UI. It is accessible by default at `http://localhost:4040/` - remember that if you are not exposing Astarte from `localhost`, you have to change Realm Management API's URL in Dashboard's configuration file, to be found in `compose/astarte-dashboard/config.json` in Astarte's repository. You can generate a token for Astarte Dashboard, as usual, through `astartectl utils gen-jwt all-realm-apis -k test_private.pem`. By default, `astartectl` will generate a token valid for 8 hours, but you can set a specific expiration by using the `-e <seconds>` parameter.

From here on, you can use all of Astarte's APIs and features from your own installation. You can add devices, experiment with interfaces, or develop your own applications on top of Astarte's triggers or AppEngine's APIs. And have a lot of fun!

## Cleaning up

When you're done with your tests and developments, you can use `docker-compose` again to tear down your Astarte instance simply by issuing:

```sh
$ docker-compose down
```

Unless you add the `-v ` option, persistencies will be kept and next time you will `docker-compose up` the cluster will come back in the very same state you left it last time. `docker-compose down -v` is extremely useful during development, especially if you want a clean slate for testing your applications or your routines every time.

## Final notes

Running Astarte through `docker-compose` is the fastest way for going from zero to hero. However, **please keep in mind this setup is unlikely to hold for long in production, and is by design broken for large installations**. We can't stop you from running such a thing in production, but do so as long as you know you voided your warranty by doing so.

This method is great for development and for trying out the system. If you wish to deploy Astarte in a more robust environment, have a look at [Astarte Enterprise](https://astarte.cloud/) or, if you want to go the DIY way, make sure that **at least** every service which requires persistency has reliable storage and adequate redundancy beneath it.
