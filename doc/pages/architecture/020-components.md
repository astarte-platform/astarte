# Components

Astarte is a distributed system interacting over AMQP, as explained in [Design Principles](010-design_principles.html). This is an overview of its main internal services.

## Pairing

Pairing takes care of Device Authentication and Authorization. It interacts with Astarte's CA and orchestrates the way devices connect and interact with Transports. It also handles Device Registration. Agent, Device and Pairing interaction is described in detail [here](050-pairing_mechanism.html).

## Data Updater Plant (DUP)

Data Updater Plant is a replicable, scalable component which takes care of the ingestion pipeline. It gathers data from devices and orchestrates data flow amongst other components. It is, arguably, the most critical component of the system and the most resource hungry - the way DUP is deployed, replicated and configured has a tremendous impact on Astarte's performances, especially when dealing with massive data flows.

## Trigger Engine

Trigger Engine takes care of processing Triggers. It is a purely computational component which handles every Trigger's pipeline and triggers actions accordingly.

## AppEngine

AppEngine is Astarte's main API endpoint for end users. AppEngine exposes a RESTful API to retrieve and send data from/to devices, according to their interfaces. Every direct device interaction can be done from here. It also exposes Channels, a WebSocket-based solution for listening to device events in real-time with Triggers' same mechanism and semantics.

## Realm Management

Realm Management is an *administrator-like* API for configuring a Realm. It is used for managing Interfaces, Triggers, Devices and more.

## Housekeeping

Housekeeping is the equivalent of a *superadmin* API. It is usually not accessible to the end user but rather to Astarte's administrator who, in most cases, might deny overall outside access. It allows to manage and create Realms, and perform cluster-wide maintenance actions.
