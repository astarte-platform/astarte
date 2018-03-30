# Managing Interfaces

[Interfaces](030-interface.html) define how data is exchanged over Astarte. For a Device to be capable of exchanging data into its Realm, its interfaces have to be registered into the Realm first. Let's walk over the whole process.

It is assumed that you have read the [Interface design guide](029-interface_design_guide.html) before, to avoid bad surprises once your fleet starts rolling.

## Querying Interfaces

To find out which interfaces are installed in a Realm, call /interfaces on your chosen realm in Realm Management API:

_Sample Request_
```
GET realm.api.<your astarte domain>/v1/test/interfaces
```

_Sample Response_
```json
["com.my.Interface1","com.my.Interface2","com.my.Interface3"]
```

This returns a list of installed interfaces inside the Realm. To retrieve a list of available major versions of a specific interface, go further in the REST tree:

_Sample Request_
```
GET realm.api.<your astarte domain>/v1/test/interfaces/com.my.Interface1
```

_Sample Response_
```json
[0,1,2]
```

In a realm, only the latest minor version of each major version of an interface is returned as a reference. This can be done due to the fact that Semantic Versioning implies a new minor doesn't introduce any breaking change (e.g.: deleting or renaming a mapping), and as such querying an older version of an interface using a newer one as a model is compatible - some mappings might be empty, as expected, and will be disregarded.

To inspect the installed interface, you can query one of its major versions:

_Sample Request_
```
GET realm.api.<your astarte domain>/v1/test/interfaces/com.my.Interface1/0
```

_Sample Response_
```
{
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
```

## Installing/Updating an interface

Interfaces are supposed to change over time, and are dynamic. As such, they can be installed and updated. Interface installation means adding either a whole new interface (as in: an interface with a new name), or a new major version of an already known interface. Interface update means updating a specific, existing interface name/major version with a new minor version.

### Installation

To install a new interface, `POST` its JSON body to the `/interfaces` endpoint of the Realm encapsulated in a `data` object, like in the following example:

```
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

In any case, the API returns details on what caused the error and how to solve it through Astarte's standard error reply schema.

It is also worth noting that interface creation is asynchronous: as such, it might be possible that `201 Created` will be returned before the interface is generally available in the Realm.

### Update

To update an existing interface, issue a `PUT` `/interfaces/<name>/<major>` endpoint of the realm with the very same semantics as the Installation procedure. The call will return either `201 Created` or an error. Apart from the very same errors that could be triggered upon installation, Update will also fail if the interface doesn't provide a compatible upgrade path from the previously installed minor.

## Interfaces lifecycle

Interfaces are versioned through a semantic versioning-like mechanism. A Realm can hold any number of interfaces and any number of major versions of a single interface. It holds, however, only the latest installed minor version of each major version, due to the inherent compatibility of Semantic Versioning.

There is no significant cost in adding a non-aggregated interface to a Realm or updating a non-aggregated interface frequently - keep in mind, however, that you might incur in [dangling data](#dangling-data) in your devices if you don't plan your interface update strategy accurately. For what concerns Aggregated interfaces, instead, there is [an inherent cost which might end up in putting pressure on your Cluster](029-interface_design_guide.html#aggregation-makes-a-difference).

Once an interface has been installed in a Realm, it can't be uninstalled without performing manual operations on Astarte's DB, unless its major version number is `0`. This is a safety measure to prevent dangling data from appearing in the cluster. For this reason, when developing an Astarte-based interface, it is strongly advised to keep its major number to `0` to allow quick changes at the expense of data loss.

Please note, however, that deleting a major `0` interface is possible if the Realm has no devices left declaring that specific interface in their introspection. This is done to avoid forever dangling data and potential consistency errors. This limitation might be lifted in the future through a mass-deletion mechanism, but there is no guarantee this will ever be done. It is advised to test new interfaces on a limited number of devices to ease operations.

## Realm vs. Device Interface relationship

There is a clear difference between how Interfaces are managed in a Realm and its Devices (e.g.: the device Introspection). Whereas a Realm can have any number of versions of a single interface, a Device is allowed to expose in its introspection only a single, specific version of an Interface.

In general, Realm interfaces are kept as a shared agreement between its entities, but when it comes to interacting with a Device, the Realm honors its introspection (as long as the Device declares interfaces the Realm is knowledgeable about).

As such, installing an interface in a Realm is a completely safe and non-disruptive operation: by design, Devices aren't aware of which interfaces a Realm supports, and Realms don't impose any interface versioning on a Device.

## Caveats

Due to how minor versions work, it is responsibility of the end user to prevent accidental data loss due to missing data. Every mapping declared in a new minor release *must* be assumed as optional, as there is no guarantee that a Device will be able to publish (or receive) data on that specific mapping.

Minor version bumps work great in case they represents additional, optional features which might be available on an arbitrarly large subset of Devices implementing that interface's major version, and are not necessary or fundamental for normal operations. If that is not the case, consider a major version update or a whole new interface instead.

Also, please keep in mind that designing interfaces in the right way, especially being as atomic as reasonably possible, helps a lot in preventing situations where a minor interface update can't be done without disrupting operations. Again, the [Interface design guide](029-interface_design_guide.html) covers this topic extensively.

## Dangling data

In several situations, it is possible to have dangling data inside Astarte. This happens by design, as the liquid nature of a Device makes it possible for data to be stored in interfaces no longer present in its introspection.

Astarte does not delete data unless requested explicitly: as such, data remains available inside its database, but potentially inaccessible through the cluster's APIs and standard mechanism.

As of the current version, Astarte has no mechanism for retrieving and acting upon a device's dangling data - this is a limitation that will be lifted in future releases with additions to the current API.

### Interface major version change

If a device upgrades one of its interfaces to a new major version, the previous interface is _parked_ and its data remains dangling. Every API call, trigger, or reference to the interface will always target the major version declared in the introspection, regardless of the fact that a more recent version might have been installed in the realm.

### Interface deletion from device

A device might arbitrarly decide to remove an interface from its introspection. In such a case, Astarte won't return any data and will consider all data previously pushed to said interface inaccessible. In case the interface comes back again in the introspection, previously pushed data will be available as if nothing happened.
