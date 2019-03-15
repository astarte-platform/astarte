# Astarte in 5 minutes

This tutorial will guide you through bringing up your Astarte instance, creating a realm and streaming your first data from a device simulator (or a real device) before your cup of tea is ready.

## Before you begin

First of all, please keep in mind that **this setup is not meant to be used in production**: by default, no persistence is involved, the installation does not have any recovery mechanism, and you will have to restart services manually in case something goes awry. This guide is great if you want to take Astarte for a spin, or if you want to use an isolated instance for development.

You will need a machine with at least 4GB of RAM (mainly due to Cassandra), with [Docker](https://www.docker.com/), [cfssl](https://github.com/cloudflare/cfssl), Python 3 and OpenSSL installed. You will need the PyJWT Python module for generating JWT tokens for Astarte, which you can install either via `pip3` (`pip3 install PyJWT`) or using your distribution's packages (e.g. `apt-get install python3-jwt` on Debian based distributions).

Also, on the machine(s) or device(s) you will use as a client, you will need either Docker, or a [Qt5](https://www.qt.io/) installation with development components if you wish to build and run components locally.

## Install Astarte

To get our Astarte instance running as fast as possible, we will install Astarte's standalone distribution. It includes a tunable Docker Compose which brings up Astarte and every companion service needed for it to work. To do so, simply clone Astarte's main repository and use its scripts to bring it up:

```sh
$ git clone https://github.com/astarte-platform/astarte.git && cd astarte
$ ./generate-compose-files.sh
$ docker-compose up -d
```

`generate-compose-files.sh` will generate a root CA for devices, a key pair for Housekeeping, and a self-signed certificate for the broker (note: this is a *really* bad idea in production). You can tune the compose file further to use legitimate certificates and custom keys, but this is out of the scope of this tutorial.

Compose might take some time to bring everything up, but usually within a minute from the containers creation Astarte will be ready. Compose will forward the following ports to your machine:

* `4000`: Realm Management API
* `4001`: Housekeeping API
* `4002`: AppEngine API
* `4003`: Pairing API
* `8883`: MQTTS
* `1885`: MQTT with Proxy Protocol for SSL termination (won't be used)
* `80`: Let's Encrypt verification (won't be used)

This example won't use Let's Encrypt with VerneMQ - in case binding to port 80 is a problem to you, you can comment it out in `docker-compose.yml` without affecting any functionality.

To check everything went fine, use `docker ps` to verify relevant containers are up: Astarte itself, VerneMQ, PostgreSQL (used by CFSSL), CFSSL, RabbitMQ and Cassandra should be now running on your system. If any of them isn't up and running, `docker ps -a` should show it stopped or failed. In those cases, it is advised to issue `docker-compose up -d` again to fix potential temporary failures.

## Create a Realm

Now that we have our instance up and running, we can start setting up a Realm for our device. We'll call our Realm `test`. Given we have no SSO or Authentication mechanism set up, we're just going to generate a public key to sign our JWTs with. You can create one with OpenSSL:

```sh
$ openssl genrsa -out test_realm.key 4096
$ openssl rsa -in test_realm.key -pubout -outform PEM -out test_realm.key.pub
$ awk '{printf "%s\\n", $0}' test_realm.key.pub > test_realm.key.pub.api
```

Also, we will need a JWT token to authenticate against Housekeeping. `generate-compose-files.sh` created a public key automatically, which is in `compose/astarte-keys/housekeeping.pub`. To generate a JWT token for authorizing our calls, we will use the handy `generate-astarte-credentials` utility in Astarte's repository, which can also be easily inlined into cURL.

Use cURL to invoke Housekeeping API for creating a new Realm:

```sh
$ curl -X POST http://localhost:4001/v1/realms -H "Authorization: Bearer $(./generate-astarte-credentials -t housekeeping -p compose/astarte-keys/housekeeping.key)" -H "Content-Type: application/json" -d "{\"data\":{\"realm_name\": \"test\", \"jwt_public_key_pem\": \"$(cat test_realm.key.pub.api)\"}}"
```

This creates a `test` realm, which should be ready to be used almost immediately. To ensure your realm is available and ready, check if it exists in Astarte by issuing:

```sh
$ curl -X GET http://localhost:4001/v1/realms -H "Authorization: Bearer $(./generate-astarte-credentials -t housekeeping -p compose/astarte-keys/housekeeping.key)"
```

## Install an interface

We will use [Astarte's Qt5 Stream Generator](https://github.com/astarte-platform/stream-qt5-test) to feed data into Astarte. Clone the repository, as we will have to install its `org.astarteplatform.Values` interface into our new realm. To do that, we can use cURL again:

```sh
$ curl -X POST http://localhost:4000/v1/test/interfaces -H "Authorization: Bearer $(./generate-astarte-credentials -t realm -p test_realm.key)" -H "Content-Type: application/json" -d "{\"data\": $(cat ../stream-qt5-test/interfaces/org.astarteplatform.Values.json)}"
```

Now `org.astarteplatform.Values` should show up among our available interfaces:

```sh
$ curl -X GET http://localhost:4000/v1/test/interfaces -H "Authorization: Bearer $(./generate-astarte-credentials -t realm -p test_realm.key)"
```

Our Astarte instance is now ready for our devices.

## Install a trigger

We will also test Astarte's push capabilities with a trigger. This will send a POST to a URL of our choice every time the value generated by `stream_test` is above 0.6.

Due to how triggers work, it is fundamental to install the trigger before a device connects. Doing otherwise will cause the trigger to kick in at a later time, and as such no events will be streamed for a while.

Replace `http://example.com` with your target URL in the command below, you can use a Postbin service like [Mailgun Postbin](http://bin.mailgun.net) to generate a URL and see the POST requests.

```sh
$ export TRIGGER_TARGET_URL="http://example.com"
$ curl -X POST http://localhost:4000/v1/test/triggers -H "Authorization: Bearer $(./generate-astarte-credentials -t realm -p test_realm.key)" -H "Content-Type: application/json" -d "{\"data\": {\"name\": \"my_trigger\", \"action\": {\"http_post_url\": \"$TRIGGER_TARGET_URL\"}, \"simple_triggers\": [{\"type\": \"data_trigger\", \"on\": \"incoming_data\", \"interface_name\": \"org.astarteplatform.Values\", \"interface_major\": 0, \"match_path\": \"/realValue\", \"value_match_operator\": \">\", \"known_value\": 0.6}]}}"
```

You can now check that your trigger is correctly installed:

```sh
curl -X GET http://localhost:4000/v1/test/triggers/my_trigger -H "Authorization: Bearer $(./generate-astarte-credentials -t realm -p test_realm.key)"
```

## Stream data

If you already have an Astarte compliant device, you can configure it and connect it straight away, and it will just work with your new installation - provided you skip SSL checks on the broker's certificate. If you don't, you can use Astarte's `stream-qt5-test` to emulate an Astarte device and generate a `datastream`. You can do this either on the same machine where you are running Astarte, or from another machine or device on the same network.

Depending on what your client supports, you can either compile `stream-qt5-test` (this will take some more time), or you can use a ready to use Docker container to launch it. Docker is the easiest and painless way, but this guide will cover both methods.

### Using a container for stream-qt5-test

Astarte's `stream-qt5-test` can be pulled from Docker Hub with:

```sh
$ docker pull astarte/astarte-stream-qt5-test:snapshot
```

Its most basic invocation (from your `astarte` repository tree) is:

```sh
$ docker run --net="host" -e "DEVICE_ID=$(./generate-astarte-device-id)" -e "PAIRING_HOST=http://localhost:4003" -e "REALM=test" -e "AGENT_KEY=$(./generate-astarte-credentials -t pairing -p test_realm.key)" -e "IGNORE_SSL_ERRORS=true" astarte/astarte-stream-qt5-test:snapshot
```

This will generate a random datastream from a brand new, random Device ID. You can tweak those parameters to whatever suits you better by having a look at the Dockerfile. You can spawn any number of instances you like, or you can have the same Device ID send longer streams of data by saving the container's persistency through a Docker Volume. If you wish to do so, simply add `-v /persistency:<your persistency path>` to your `docker run` invocation.

Refer to `stream-qt5-test` [README](https://github.com/astarte-platform/stream-qt5-test/blob/master/README.md) for more details on which variables can be passed to the container.

Also, please note that the `--net="host"` parameter is required to make `localhost` work. If this is not desirable, you can change `PAIRING_HOST` to an host reachable from within the container network. Obviously, that parameter isn't required if you're running the container on a different machine and `PAIRING_HOST` is pointing to a different URL.

## Building stream-qt5-test from source

If your target platform does not support running containers, you can build `stream-qt5-test` from source. To do so, you will have to compile both Astarte Qt5 SDK and Astarte Qt5 Stream Test. Their main dependencies are `cmake`, `qtbase`, `mosquitto` and `openssl`. If you're on a Debian derivative, you can install them all with:

```sh
# apt-get install qt5-default qtbase5-dev libqt5sql5-sqlite libssl-dev libmosquittopp-dev cmake git build-essential
```

Once your dependencies are installed, compile your components:

```sh
$ git clone https://github.com/astarte-platform/astarte-device-sdk-qt5.git
$ cd astarte-device-sdk-qt5
$ mkdir build
$ cd build
$ cmake -DCMAKE_INSTALL_PREFIX=/usr ..
$ make
$ make install
$ cd -
$ git clone https://github.com/astarte-platform/stream-qt5-test.git
$ cd stream-qt5-test
$ qmake .
$ make
```

You can now run `stream-qt5-test` from your last build directory. Refer to its [README](https://github.com/astarte-platform/stream-qt5-test/blob/master/README.md) (or to its sources) to learn about how to use it and which options are available.

## Grab your tea

Congratulations! Your devices or fake devices are now communicating with Astarte, and your tea should be ready by now. You can check if everything is working out by invoking AppEngine APIs to get some values. In case you are using `stream-qt5-test`, you can get the last sent value via cURL:

```sh
$ curl -X GET "http://localhost:4002/v1/test/devices/<your device id>/interfaces/org.astarteplatform.Values/realValue?limit=1" -H "Authorization: Bearer $(./generate-astarte-credentials -t appengine -p test_realm.key)"
```

If you get a meaningful value, congratulations - you have a working Astarte installation with your first `datastream` coming in!

Moreover, Astarte's Docker Compose also installs [Astarte Dashboard](https://github.com/astarte-platform/astarte-dashboard), from which you can manage your Realms and install Triggers, Interfaces and more from a Web UI. It is accessible by default at `http://localhost:4040/` - remember that if you are not exposing Astarte from `localhost`, you have to change Realm Management API's URL in Dashboard's configuration file, to be found in `compose/astarte-dashboard/config.json` in Astarte's repository. You can generate a token for Astarte Dashboard, as usual, through `./generate-astarte-credentials -t realm -p test_realm.key`. Grant a longer expiration by using the `-e` parameter to avoid being logged out too quickly.

From here on, you can use all of Astarte's APIs and features from your own installation. You can add devices, experiment with interfaces, or develop your own applications on top of Astarte's triggers or AppEngine's APIs. And have a lot of fun!

## Cleaning up

When you're done with your tests and developments, you can use `docker-compose` again to tear down your Astarte instance simply by issuing:

```sh
$ docker-compose down
```

Unless you add the `-v ` option, persistencies will be kept and next time you will `docker-compose up` the cluster will come back in the very same state you left it last time. `docker-compose down -v` is extremely useful during development, especially if you want a clean slate for testing your applications or your routines every time.

## Troubleshooting

### Could not generate credentials

If `astarte-generate-credentials` fails with this error
```
Traceback (most recent call last):
  File "./generate-astarte-credentials", line 37, in <module>
    encoded = jwt.encode(claims, private_key_pem, algorithm="RS256")
AttributeError: module 'jwt' has no attribute 'encode'
```
you have to remove the conflicting `jwt` pip package by uninstalling it with `pip3 uninstall jwt`.

## Final notes

Running Astarte through `docker-compose` is the fastest way for going from zero to hero. However, **please keep in mind this setup is unlikely to hold for long in production, and is by design broken for large installations**. We can't stop you from running such a thing in production, but do so as long as you know you voided your warranty by doing so.

This method is great for development and for trying out the system. If you wish to deploy Astarte in a more robust environment, have a look at [Astarte Enterprise](https://astarte.cloud/) or, if you want to go the DIY way, make sure that **at least** every service which requires persistency has reliable storage and adequate redundancy beneath it.
