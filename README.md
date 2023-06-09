# Astarte

![](https://github.com/astarte-platform/astarte/workflows/Build%20and%20Test%20Astarte%20Apps/badge.svg?branch=master)
[![codecov](https://codecov.io/gh/astarte-platform/astarte/branch/master/graph/badge.svg)](https://codecov.io/gh/astarte-platform/astarte)

<img src="doc/images/mascotte.svg" align="left" width="160px" />Astarte is an Open Source IoT
platform focused on Data management and processing written in [Elixir](https://github.com/elixir-lang/elixir).
It is a turnkey solution which packs in everything you need for connecting a device fleet to a set of
remote applications and process data as it flows through a set of built-in features.

It performs data modeling, automated data reduction, real-time events,
and provides you with any feature you might expect in a modern IoT platform.

Astarte builds on top of amazing Open Source projects such as [RabbitMQ](https://www.rabbitmq.com/)
and [Cassandra](http://cassandra.apache.org/)/[ScyllaDB](https://www.scylladb.com/).

## Resources and Quickstart

 * [Astarte Documentation](https://docs.astarte-platform.org) - The main resource to learn about
   Astarte.
 * [astartectl](https://github.com/astarte-platform/astartectl) - A Command Line tool to manage your
   Astarte cluster(s).
 * [Astarte Kubernetes Operator](https://github.com/astarte-platform/astarte-kubernetes-operator) -
   The preferred and supported way to run Astarte - in Production, and pretty much anywhere else.
 * Device SDKs - Connect your device to Astarte in a few lines of code. Available for
   [Python](https://github.com/astarte-platform/astarte-device-sdk-python),
   [Qt5](https://github.com/astarte-platform/astarte-device-sdk-qt5),
   [ESP32](https://github.com/astarte-platform/astarte-device-sdk-esp32),
   [Elixir](https://github.com/astarte-platform/astarte-device-sdk-elixir) and counting.

## Let's try it!

**This is the master branch, which is not guaranteed to always be in a usable state.**

**For production purposes we recommend using the latest stable release (currently [v1.0.1](https://github.com/astarte-platform/astarte/tree/release-1.0)), this branch should be used only for 1.1 development activities.**

Can't be easier. Pick your favorite machine with at least 4GB of free RAM, make sure it has
[Docker](https://www.docker.com/), and simply:

```sh
$ git clone https://github.com/astarte-platform/astarte.git && cd astarte
$ docker run -v $(pwd)/compose:/compose astarte/docker-compose-initializer:snapshot
$ docker-compose pull
$ docker-compose up -d
```

Make sure to use the latest stable release if you want a flawless experience.

You should be up and running in a matter of minutes. If you want a more thorough explanation and
find out how to access your new Astarte cluster and what you can do with it, [follow our "Astarte in
5 minutes" tutorial](https://docs.astarte-platform.org/astarte/1.1/010-astarte_in_5_minutes.html) to
get some fake or real devices to stream and process data while your tea gets ready.

## Sweet! Let's move it to production!

Whoa, not so fast. Putting together an Astarte instance which can handle your data might be
tricky, and requires some knowledge about the platform to make sure it won't break.

So, if you're serious about getting Astarte in your production environment, you might want to learn
more about it first. Start by [having a look at its
architecture](https://docs.astarte-platform.org/astarte/1.1/001-intro_architecture.html) and
[finding out how it works](https://docs.astarte-platform.org/astarte/1.1/001-intro_user.html). Once
you feel confident, head over to the [Administration
Manual](https://docs.astarte-platform.org/astarte-kubernetes-operator/22.11/001-intro_administrator.html).

## Where do I find binaries?

Astarte is designed from the ground up to be run in containers, with
[Kubernetes](https://github.com/kubernetes/kubernetes) as a first-class citizen when it comes to
deployment. Astarte's images can be found at [Docker Hub](https://hub.docker.com/u/astarte/), with
every Astarte service coming with its own image.

With the help of our [Kubernetes
Operator](https://github.com/astarte-platform/astarte-kubernetes-operator) and
[`astartectl`](https://github.com/astarte-platform/astartectl), you can deploy your Astarte instance
to your favorite cloud provider in a matter of minutes.

## Looks great! I want to contribute!

That's awesome! Astarte is quite young as an Open Source project, so we're still setting up bits and
pieces to make contributions easier and more effective, such as a shared roadmap, a proper
contributor guide. For the time being, you can head over to the repository you want to contribute to
and set up a Pull Request. We're using [DCO](https://developercertificate.org/) for our
contributions, so you'll need to sign off all commit messages before submitting a Pull Request.

You can also join us on [#astarte slack channel on Elixir
Slack](https://elixir-slackin.herokuapp.com/) and on [#astarte IRC channel on
freenode](ircs://chat.freenode.net:6697/#astarte).

We accept all kind of quality contributions, as long as they adhere with the project goals and
philosophy, and have some tests.

## Any chance I can get a hosted and managed instance?

Yup, stay tuned :) or get in touch with us.

## I need some help with my installation! Where can I get commercial support?

Glad you asked. Astarte is developed by SECO Mind, who fuels its development thanks to the
generosity of many customers running it in production. Besides consultancy, installation,
maintenance, long-term support and customizations, SECO Mind also commercializes Astarte Enterprise,
an Astarte variant packing in some additional goodies and features.

[Get in touch](https://astarte.cloud/contactus) or [contact us via email](mailto:info@secomind.com)
to find out how we can help you in getting Astarte in its best possible shape for your specific
needs.

# License

Astarte source code is released under the Apache 2 License.

Check the LICENSE file for more information.
