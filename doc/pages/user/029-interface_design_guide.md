# Interface Design Guide

Before we begin, let's get this straight:

> **The way you design your interfaces will determine the overall performance and efficiency of your cluster**

This is because interfaces define not only the way data is exchanged between Astarte and Devices/Applications, but also **how it will be stored, managed and queried**. As such, it is fundamental to spend enough time on finding the most correct Interface design for your use case, keeping in mind how your users will consume your data, what might change in the future, what is fundamental and what is optional, and more.

## Rationale

Without going into deeper details on what concerns Astarte's DB internals, there are some considerations one should always keep in mind when designing interfaces.

### Querying an Interface is fast, querying across Interfaces is painful

Astarte's data modeling is designed to optimize queries within a single interface. Querying across interfaces is supported, but might affect performances significantly, especially if done frequently and with complex queries. This is especially true for triggers, as they could be evaluated very frequently.

In general, if you plan on having different mappings which are frequently queried altogether, or dependent on each other for several triggers, you might be better off in having them all in the same Interface.

### Aggregation makes a difference

Aggregation is a powerful feature, which comes with price and benefits. Even though each series has only one timestamp for all values, it is also true that losing granularity for endpoints might cause storage of redundant data if only one of the aggregated mappings change value.

Moreover, in terms of data modeling, Aggregated interfaces imply the creation of a dedicated Cassandra table. Having a lot of aggregated interfaces might end up putting additional pressure on the Cassandra Cluster in terms of memory and overall performance. Your Cluster administrator might (rightfully) choose to limit the amount of installed aggregate interfaces in a Realm, or in the overall Cluster.

## Interface Atomicity

Rule of thumb:

> Favor extreme atomicity in case you expect your interfaces to change often, be as atomic as reasonably possible in case you want to favor performance and flexibility in querying data.
