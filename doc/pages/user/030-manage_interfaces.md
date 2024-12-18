<!--
Copyright 2018-2021 SECO Mind Srl

SPDX-License-Identifier: Apache-2.0
-->

# Managing Interfaces

[Interfaces](030-interface.html) define how data is exchanged over Astarte. For a Device to be
capable of exchanging data into its Realm, its interfaces have to be registered into the Realm
first. Let's walk over the whole process.

It is assumed that you have read the [Interface design guide](029-interface_design_guide.html)
before, to avoid bad surprises once your fleet starts rolling.

## Querying Interfaces

### Listing Interfaces

You can list all installed interfaces in a given Realm. This will return all the valid installed
Interface names, without any versioning.

#### List Interfaces using astartectl

```bash
$ astartectl realm-management interfaces list
[com.my.Interface1 com.my.Interface2 com.my.Interface3]
```

#### List Interfaces using Astarte Dashboard

From your Dashboard, after logging in, click on "Interfaces" in the left menu.

#### List Interfaces using Realm Management API

`GET <astarte base API URL>/realmmanagement/v1/test/interfaces`

```json
{"data": ["com.my.Interface1","com.my.Interface2","com.my.Interface3"]}
```

### Listing Major Versions for an Interface

For each installed Interface, there can be any number of Major versions installed. This information
can be retrieved by listing the available Major versions for a specific interface.

In a realm, only the latest minor version of each major version of an Interface is kept. This can be
done due to the fact that Semantic Versioning implies a new minor version doesn't introduce any
breaking change (e.g.: deleting or renaming a mapping), and as such querying an older version of an
interface using a newer one as a model is always compatible - some mappings might be empty, as
expected, and will be disregarded. Astarte ensures upon Interface installation for this constraint,
and as such you can always query the latest minor version of an Interface safely.

#### List Versions using astartectl

```bash
$ astartectl realm-management interfaces versions com.my.Interface1
[0 1 2]
```

#### List Versions using Astarte Dashboard

In the Dashboard's Interface page, click on any Interface name. A drop-down will appear, showing
installed major versions for that Interface name.

#### List Versions using Realm Management API

`GET <astarte base API URL>/realmmanagement/v1/test/interfaces/com.my.Interface1`

```json
{"data": [0,1,2]}
```

#### Getting an Interface Definition

Astarte allows you to retrieve the Interface Definition for a given Name and Major Version pair. The
definition is in the standard Interface JSON format.

### Get Interface Definition using astartectl

```bash
$ astartectl realm-management interfaces show com.my.Interface1 0
{
  "data": {
    "version_minor": 2,
    "version_major": 0,
    "type": "properties",
    "ownership": "device",
    "mappings": [
      {
        "type": "integer",
        "path": "/myValue",
        "description": "This is quite an important value."
      },
      {
        "type": "integer",
        "path": "/myBetterValue",
        "description": "A better revision, introduced in minor 2, supported only by some devices"
      },
      {
        "type": "boolean",
        "path": "/awesome",
        "allow_unset": true,
        "description": "Introduced in minor 1, tells you if the device is awesome. Optional."
      }
    ],
    "interface_name": "com.my.Interface1"
  }
}
```

### Get Interface Definition using Astarte Dashboard

From the Interfaces page, click on an Interface name, and click on the Major version for which you'd
like to see the definition. The Interfaces Editor window will open, with the Interface definition in
the text box on the right. From the Editor page, it is also possible to add new mappings to the
Interface and bump it to a new Minor.

### Get Interface Definition using Realm Management API

`GET <astarte base API URL>/realmmanagement/v1/test/interfaces/com.my.Interface1/0`

```json
{
  "data": {
    "version_minor": 2,
    "version_major": 0,
    "type": "properties",
    "ownership": "device",
    "mappings": [
      {
        "type": "integer",
        "path": "/myValue",
        "description": "This is quite an important value."
      },
      {
        "type": "integer",
        "path": "/myBetterValue",
        "description": "A better revision, introduced in minor 2, supported only by some devices"
      },
      {
        "type": "boolean",
        "path": "/awesome",
        "allow_unset": true,
        "description": "Introduced in minor 1, tells you if the device is awesome. Optional."
      }
    ],
    "interface_name": "com.my.Interface1"
  }
}
```

## Installing/Updating an interface

Interfaces are supposed to change over time, and are dynamic. As such, they can be installed and
updated. Interface installation means adding either a whole new Interface (as in: an Interface with
a new name), or a new major version of an already known Interface. Interface update means updating a
specific, existing interface name/major version with a new minor version.

When designing interfaces, it is strongly advised to use Astarte Interface Editor. The Editor is
embedded into any Astarte Dashboard installation but, in case your Astarte installation does not
provide you with a Dashboard, you can use [Astarte Interface Editor public online
instance](https://interfaces-editor.astarte-platform.org). Use it to write and validate your
definitions, and install the resulting JSON file through either `astartectl` or Realm Management
APIs.

### Synchronizing interfaces using astartectl

`astartectl` provides a handy `sync` command that, given a list of Interface files, will synchronize
the state of the Astarte Realm with your local interfaces. It is handy in those cases where your
Realm has several interfaces, and you're storing Interfaces in a common place, such as a Git
Repository - this is the average case for Astarte-based applications/clouds.

Assuming you have a set of Interface files in your folder all with the `.json` extension, invoking
`astartectl realm-management interfaces sync` will result in something like this:

```bash
$ astartectl realm-management interfaces sync *.json
Will install interface com.my.Interface1 version 0.2
Will install interface com.my.Interface2 version 1.1
Will update interface com.my.Interface3 to version 1.4

Do you want to continue? [y/n] y
Interface com.my.Interface1 installed successfully
Interface com.my.Interface2 installed successfully
Interface com.my.Interface3 updated successfully to version 1.4
```

After invocation, your Astarte Realm will be up to date with all Interfaces in your local directory.

*Note: `astartectl realm-management interfaces sync` currently synchronizes Interfaces only from
your local machine to the Realm, and not the other way round. In case the Realm has a more recent
version of an interface compared to your local files, or it has some interfaces which are not
referenced by your local files, no action will be taken.*

### Install an Interface using Astarte Dashboard

Access the Editor by going to the Interfaces page, and clicking on "Install a New Interface..." in
the top-right corner. The Editor will open. From there, you can either paste in an existing JSON
definition, which will be validated and will update the left-screen declarative Editor, or you can
build a whole new Interface from scratch.

Once you're done, hit the "Install Interface" button at the bottom of the declarative Editor (left
side) to install the Interface in the Realm.

### Install an Interface using astartectl

First of all, ensure that you have the Interface you'd like to install saved in a file on your local
machine. We will assume the interface is available as `interface1.json`.

```bash
$ astartectl realm-management interfaces install interface1.json
ok
```

### Install an Interface using Realm Management API

Realm Management currently implements a completely asynchronous API for Interface installation - as
such, the only feedback received by the API is that the Interface is valid and the request was
accepted by the backend. However, this is no guarantee that the Interface will be installed
successfully. As a best practice, it is advised to either wait a few seconds in between Realm
Management API invocations, or verify through a `GET` operation whether the Interface has been
installed or not.

`POST <astarte base API URL>/realmmanagement/v1/test/interfaces`

The POST request must have the following request body, with content type `application/json`

```json
{
  "data": {
    "version_minor": 2,
    "version_major": 0,
    "type": "properties",
    "ownership": "device",
    "mappings": [
      {
        "type": "integer",
        "path": "/myValue",
        "description": "This is quite an important value."
      },
      {
        "type": "integer",
        "path": "/myBetterValue",
        "description": "A better revision, introduced in minor 2, supported only by some devices"
      },
      {
        "type": "boolean",
        "path": "/awesome",
        "allow_unset": true,
        "description": "Introduced in minor 1, tells you if the device is awesome. Optional."
      }
    ],
    "interface_name": "com.my.Interface1"
  }
}
```

The call will return either `201 Created` or an error. Most common failure cases are:

* The interface/major combination already exists in the Realm
* The interface schema fails validation

In any case, the API returns details on what caused the error and how to solve it through Astarte's
standard error reply schema.

### Update an Interface using astartectl

First of all, ensure that you have the Interface you'd like to update saved in a file on your local
machine. We will assume the interface is available as `interface1_3.json`.

```bash
$ astartectl realm-management interfaces update interface1_3.json
ok
```

### Update an Interface using Astarte Dashboard

Go to the Interfaces page, click on the Interface Name you'd like to update, and click on the Major
version which is referred by your upgrade (e.g.: if you're updating from 1.2 to 1.3, you want to
click on Major Version 1). The Editor will appear, populated with the currently installed Interface
definition. Paste in your updated JSON file, or use the declarative editor to make your changes. The
editor will be limited to Semantic Version-compatible operations (as in - adding new mappings).

Once you're done, hit the "Apply Changes" button at the bottom of the declarative Editor (left side)
to update the Interface in the Realm.

### Update an Interface using Realm Management API

To update an existing interface, issue a `PUT` `/interfaces/<name>/<major>` endpoint of the realm
with the very same semantics as the Installation procedure. The call will return either `201
Created` or an error. Apart from the very same errors that could be triggered upon installation,
Update will also fail if the interface doesn't provide a compatible upgrade path from the previously
installed minor.

### Interface update limitations

#### Major version updates

Major version updates have no intrinsic limitations as they are not meant to ensure compatibility
with older versions of the same interface. Therefore, if you plan to bump your interface major you
are allowed to update your interface at your preference. Please, refer to the [Interface Design
Guide](029-interface_design_guide.html) to follow the best practices while developing your new
updated interface.

#### Minor version updates

Minor version updates are conceived to guarantee retro-compatibility and, as such, they allows only
for a limited subset of update operations.

Currently, based on the interface type and aggregation, different update capabilities are provided:

- `properties`:
  - at interface root level, `doc` and `description` updates are allowed;
  - at mapping level, `doc` and `description` updates are allowed. Moreover, an arbitrary number of
    new mappings can be added;

- `individual datastream`:
  - at interface root level, `doc` and `description` updates are allowed;
  - at mapping level, `doc`, `description` and `explicit_timestamp` updates are allowed. Moreover,
    an arbitrary number of new mappings can be added;

- `object aggregated datastream`:
  - currently, due to a limitation in how data are stored within Cassandra, the `doc`, `descriprion`
    and `explicit-timestamp` fields *can not* be updated;
  - at mapping level, an arbitrary number of mappings can be added.

Where not explicitly stated, all the other values are to be considered as not updatable. In case you
need to update one of those fields, please consider updating your interface major version.

## Interfaces lifecycle

Interfaces are versioned through a semantic versioning-like mechanism. A Realm can hold any number
of interfaces and any number of major versions of a single interface. It holds, however, only the
latest installed minor version of each major version, due to the inherent compatibility of Semantic
Versioning.

There is no significant cost in adding a non-aggregated interface to a Realm or updating a
non-aggregated interface frequently - keep in mind, however, that you might incur in [dangling
data](#dangling-data) in your devices if you don't plan your interface update strategy accurately.
For what concerns Aggregated interfaces, instead, there is [an inherent cost which might end up in
putting pressure on your Cluster](029-interface_design_guide.html#aggregation-makes-a-difference).

Once an interface has been installed in a Realm, it can't be uninstalled without performing manual
operations on Astarte's DB, unless its major version number is `0`. This is a safety measure to
prevent dangling data from appearing in the cluster. For this reason, when developing an
Astarte-based interface, it is strongly advised to keep its major number to `0` to allow quick
changes at the expense of data loss.

Please note, however, that deleting a major `0` interface is possible if the Realm has no devices
left declaring that specific interface in their introspection. This is done to avoid forever
dangling data and potential consistency errors. This limitation might be lifted in the future
through a mass-deletion mechanism, but there is no guarantee this will ever be done. It is advised
to test new interfaces on a limited number of devices to ease operations.

## Realm vs. Device Interface relationship

There is a clear difference between how Interfaces are managed in a Realm and its Devices (e.g.: the
device Introspection). Whereas a Realm can have any number of versions of a single interface, a
Device is allowed to expose in its introspection only a single, specific version of an Interface.

In general, Realm interfaces are kept as a shared agreement between its entities, but when it comes
to interacting with a Device, the Realm honors its introspection (as long as the Device declares
interfaces the Realm is knowledgeable about).

As such, installing an interface in a Realm is a completely safe and non-disruptive operation: by
design, Devices aren't aware of which interfaces a Realm supports, and Realms don't impose any
interface versioning on a Device.

## Caveats

Due to how minor versions work, it is responsibility of the end user to prevent accidental data loss
due to missing data. Every mapping declared in a new minor release *must* be assumed as optional, as
there is no guarantee that a Device will be able to publish (or receive) data on that specific
mapping.

Minor version bumps work great in case they represents additional, optional features which might be
available on an arbitrarly large subset of Devices implementing that interface's major version, and
are not necessary or fundamental for normal operations. If that is not the case, consider a major
version update or a whole new interface instead.

Also, please keep in mind that designing interfaces in the right way, especially being as atomic as
reasonably possible, helps a lot in preventing situations where a minor interface update can't be
done without disrupting operations. Again, the [Interface design
guide](029-interface_design_guide.html) covers this topic extensively.

## Dangling data

In several situations, it is possible to have dangling data inside Astarte. This happens by design,
as the liquid nature of a Device makes it possible for data to be stored in interfaces no longer
present in its introspection.

Astarte does not delete data unless requested explicitly: as such, data remains available inside its
database, but potentially inaccessible through the cluster's APIs and standard mechanism.

As of the current version, Astarte has no mechanism for retrieving and acting upon a device's
dangling data - this is a limitation that will be lifted in future releases with additions to the
current API.

### Interface major version change

If a device upgrades one of its interfaces to a new major version, the previous interface is
_parked_ and its data remains dangling. Every API call, trigger, or reference to the interface will
always target the major version declared in the introspection, regardless of the fact that a more
recent version might have been installed in the realm.

### Interface deletion from device

A device might arbitrarly decide to remove an interface from its introspection. In such a case,
Astarte won't return any data and will consider all data previously pushed to said interface
inaccessible. In case the interface comes back again in the introspection, previously pushed data
will be available as if nothing happened.
