# Device errors

This page details the errors that can affect a device while it's sending data. The user can monitor
device errors by installing a [device trigger](060-triggers.html#device-triggers) on `device_error`
or checking the Devices tab in the Astarte Dashboard. The same errors are also provided as log
messages on Data Updater Plant.

## `write_on_server_owned_interface`

The device is trying to write on a server owned interface. The device can only push data on device
owned interfaces.

## `invalid_interface`

The interface name received in the message is invalid.

## `invalid_path`

The path received in the message is invalid. This might happen when a path does not have a valid
path format or it's not a valid UTF-8 string.

## `mapping_not_found`

The path received in the message can't be found in the interface mappings. This could be the result
of the device having a more recent version of the inteface than the one installed in the realm or an
interface with the same name and version but different contents.

## `interface_loading_failed`

The target interface was not found in the database. Usually this means the interface is not
installed in the realm, but the error can also derive from the database being temporarily
unavailable.

## `ambiguous_path`

The path received in the message can't be mapped univocally on a mapping. This is often the result
of an incomplete path.

## `undecodable_bson_payload`

The payload of the message can't be decoded as BSON.

## `unexpected_value_type`

The value of the message does not have the expected type (_e.g._ the mapping expects a string value
but an integer value was received instead).

## `value_size_exceeded`

The value of the message exceeds the maximum size of its type. The size limitations of the types are
documented [here](030-interface.html#supported-data-types).

## `unexpected_object_key`

An object aggregated value with an unexpected key was received.

## `invalid_introspection`

The introspection sent from the device can't be parsed correctly. The introspection format is
documented [here](080-mqtt-v1-protocol.html#introspection).

## `unexpected_control_message`

The device sent a message on an unhandled control path. The supported control paths are detailed in
the [protocol documentation](080-mqtt-v1-protocol.html#introspection).

## `device_session_not_found`

Data Updater Plant failed to push data towards the device. This could result from the device being
currently offline and not having a persistent session on the MQTT broker or from the device not
having all the [MQTT subscriptions required by the Astarte
protocol](https://docs.astarte-platform.org/astarte/1.0/080-mqtt-v1-protocol.html#mqtt-topics-overview)

## `resend_interface_properties_failed`

Data Updater Plant failed to resend the properties of an interface. This could result from the
device declaring a uninstalled properties interface in its introspection right before an emptyCache.

## `empty_cache_error`

The empty cache operation for a device failed. This could result from a temporary database failure.
