# Astarte: An Open Source IoT Platform

<img src="doc/images/mascotte.svg" align="left" width="160px" />Astarte is an Open Source IoT platform written in [Elixir](https://github.com/elixir-lang/elixir). It is a turnkey solution which packs in everything you need for connecting a device fleet to a set of remote applications. It performs data modeling, automated data reduction, real-time events, and provides you with any feature you might expect in a modern IoT platform.

Astarte builds on top of amazing Open Source projects such as [RabbitMQ](https://www.rabbitmq.com/) and [Cassandra](http://cassandra.apache.org/)/[ScyllaDB](https://www.scylladb.com/).

## Let's try it!

**This Astarte version has been discontinued and it is not supported anymore.**

**Do not use this version on production systems, use a newer version instead.**

Can't be easier.
Pick your favorite machine with at least 4GB of RAM (Cassandra can be hungry), make sure it has [Docker](https://www.docker.com/), [cfssl](https://github.com/cloudflare/cfssl) and OpenSSL installed, and simply:

```sh
$ git clone https://github.com/astarte-platform/astarte.git -b release-0.10 && cd astarte
$ ./generate-compose-files.sh
$ docker-compose up -d
```

You should be up and running in a matter of minutes. If you want a more thorough explanation and find out how to access your new Astarte cluster and what you can do with it, [follow our "Astarte in 5 minutes" tutorial](https://docs.astarte-platform.org/latest/010-astarte_in_5_minutes.html) to get some fake or real devices to stream and process data while your tea gets ready.

## Sweet! Let's move it to production!

Whoa, not so fast. Putting together an Astarte instance which can handle your IoT traffic might be tricky, and requires some knowledge about the platform to make sure it won't break.

So, if you're serious about getting Astarte in your production environment, you might want to learn more about it first. Start with [having a look at its architecture](https://docs.astarte-platform.org/latest/001-intro_architecture.html) and [finding out how it works](https://docs.astarte-platform.org/latest/001-intro_user.html). Once you feel confident, head over to the [Administration Manual](https://docs.astarte-platform.org/latest/001-intro_administrator.html) to find out how to make Astarte fit into your infrastructure, and which deployment mechanism you should choose.

## Where's all the code, anyway?

Good question. This repository is a collection of utilities, home to Astarte's documentation and architecture decisions, and acts as an umbrella for the project. Astarte is a distributed system made up of several microservices, [which can all be found in Github](https://github.com/astarte-platform). Its core components are:

* [Data Updater Plant](apps/astarte_data_updater_plant): Takes care of ingesting data into the database, filtering and routing it to other Astarte components.
* [Trigger Engine](apps/astarte_trigger_engine): Processes incoming events, applies rules, prepares payloads and performs actions - it is the component that delivers data to your application.
* [AppEngine API](apps/astarte_appengine_api): If you are building an application on top of Astarte's APIs, you will most likely call into it.
* [Pairing](apps/astarte_pairing) & [Pairing API](apps/astarte_pairing_api): Provides all the information required to successfully communicate with Astarte, including the SSL certificate.
* [Realm Management](apps/astarte_realm_management) & [Realm Management API](apps/astarte_realm_management_api): Where realm configuration happens. Manage your triggers, interfaces and more from here.
* [Housekeeping](apps/astarte_housekeeping) & [Housekeeping API](apps/astarte_housekeeping_api): The *"superadmin"* component of Astarte: configure your global instance, create realms and more.

All of them build on some common libraries:

* [Astarte Core](https://github.com/astarte-platform/astarte_core): All common functions and anything useful to Astarte's services go here.
* [Astarte RPC](https://github.com/astarte-platform/astarte_rpc): Defines [protobuf](https://developers.google.com/protocol-buffers/) messages to allow all of Astarte's services to talk together.
* [Astarte Data Access](https://github.com/astarte-platform/astarte_data_access): Commodity component which abstracts data access for services which need it.

Astarte also needs a transport to communicate with devices:

* [Astarte's VerneMQ plugin](https://github.com/astarte-platform/astarte_vmq_plugin): Turns the amazing [VerneMQ](https://github.com/erlio/vernemq) into a full fledged Astarte Transport.

## What about the binaries?

Astarte is designed from the ground up to be run in containers, with [Kubernetes](https://github.com/kubernetes/kubernetes) as a first-class citizen when it comes to deployment. Astarte's images can be found at [Docker Hub](https://hub.docker.com/u/astarte/), with every Astarte service coming with its own image.

If you don't fancy containers, we plan on providing standalone binary packages soon.

## Looks great! I want to contribute!

That's awesome! Astarte is quite young as an Open Source project, so we're still setting up bits and pieces to make contributions easier and more effective, such as a shared roadmap, a proper contributor guide. For the time being, you can head over to the repository you want to contribute to and set up a Pull Request. There's a CLA to be signed, as we plan on moving Astarte to a more permissive license very soon.

You can also join us on [#astarte slack channel on Elixir Slack](https://elixir-slackin.herokuapp.com/) and on [#astarte IRC channel on freenode](ircs://chat.freenode.net:6697/#astarte).

We accept all kind of quality contributions, as long as they adhere with the project goals and philosophy, and have some tests.

## Any chance I can get a hosted and managed instance?

Yup. Some infrastructure and cloud providers are working on releasing Astarte-based SaaS services, and we're also working on making Astarte deployable onto major cloud providers in the easiest possible way. Watch this space or subscribe to our newsletter to find out more about it.

## I need some help with my installation! Where can I get commercial support?

Glad you asked. Astarte is developed by [Ispirata](https://ispirata.com), who fuels its development thanks to the generosity of many customers running it in production. Besides consultancy, installation, maintenance, long-term support and customizations, Ispirata also commercializes Astarte Enterprise, an Astarte variant packing in some additional goodies and features, such as a Kubernetes Operator.

[Get in touch](https://ispirata.com/contact/) to find out how we can help you in getting Astarte in its best possible shape for your specific needs.

# License

Astarte source code is released under Apache 2 License.

Check LICENSE file for more information.
