# Introduction

<img align="right" src="assets/mascot_developer.svg" style="border:20px solid transparent" alt="Join Puppy Lion and have some fun with Astarte!" width="40%" />

Astarte is an Open Source IoT platform focused on Data management. It takes care of everything from collecting data from devices to delivering data to end-user applications. To achieve such a thing, it uses a mixture of mechanisms and paradigm to store organized data, perform live queries.

This guide focuses on daily operations for Astarte users and integrators. It goes through fundamental operations such as setting up triggers, querying APIs, integrating 3rd party applications and more.

The user guide starts from the assumption that the reader is interacting with [one or more well-known realms](010-design_principles.html#realms-and-multitenancy), and throughout the manual the assumption is that we're always operating inside a `test` realm, unless otherwise specified.

Setting up realms is out of the scope of this guide, also because it's not a task the average user has to deal with. Please refer to the [dedicated chapter of the Administrator manual](070-manage_realms.html) to learn more about this specific topic.

Before you begin, make sure you are familiar with [Astarte's architecture, design and concepts](001-intro_architecture.html).
