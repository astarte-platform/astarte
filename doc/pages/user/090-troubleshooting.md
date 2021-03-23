# Troubleshooting

Be sure to check [known issues](095-known_issues.html) to see if your problem is already covered
there.

## Devices

### Devices cannot connect to Astarte

#### There might be some network issues or network misconfiguration

Devices need a working network connection in order to communicate with Astarte. There might be some temporary network issues, or any network setting or appliance might not be properly configured. Make sure that devices are allowed to make outbound connections on ports 443 (https) and any port the transport needs for accepting connections from devices. For Astarte/VerneMQ, this defaults to 8883 (MQTT over SSL), but might also be configured otherwise.

#### SSL issues

Devices need to be able to connect to Astarte using SSL. Make sure that the clock has been synched to avoid certificate issue/expiry date errors, make also sure to have all the root CAs up to date.

### Device gets disconnected from Astarte

#### Some interfaces might be missing

When a device reports an interface that Astarte doesn't have, it gets disconnected when the introspection is published. Make sure that all device interfaces have been previously installed on Astarte. Make also sure that interface name and major exactly matches installed version.

#### Device is publishing unexpected or malformed data

When a device sends invalid, malformed or unexpected data it gets disconnected, make sure that the device is sending valid data. An interface mismatch might be the most common reason for this kind of issues. e.g. the interface has been declared device owned on the device, and astarte owned on astarte. Make sure to use exactly the same JSON file on both ends.

## Triggers

### Triggers are not executed

#### Triggers have not been loaded yet

Triggers might take some time before being loaded for devices that have been recently connected, make sure to wait some time before the triggers cache is populated again.
If you are on a hurry make sure to test a trigger on a device that has not been recently connected yet.
