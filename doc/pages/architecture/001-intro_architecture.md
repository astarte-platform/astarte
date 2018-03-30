# Introduction

<img align="right" src="assets/mascot_architecture.svg" style="border:20px solid transparent" alt="Join Puppy Lion and have some fun with Astarte!" width="40%" />

Astarte is a collection of components written in [Elixir](http://elixir-lang.org/) meant to orchestrate and pilot a number of 3rd party components. These components include:

* One or more ingresses (the most popular implementation being an MQTT broker)
* An AMQP broker for handling messages and queues between Astarte's services
* A Cassandra-like Database for ingesting and retrieving data (currently [Cassandra](http://cassandra.apache.org/) and [ScyllaDB](http://scylladb.com) are both supported)

These components are never directly exposed to Astarte's end user, who requires no knowledge whatsoever of the mentioned frameworks - they are rather orchestrated and managed directly by Astarte's services. It is, however, responsability of Astarte's administrators to make sure these services are made available the way they are meant to.

For more details on this topic and, in general, on how to deal with Astarte's installation and maintenance, please refer to the [Administrator Guide](001-intro_administrator.html).
