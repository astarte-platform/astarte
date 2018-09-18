# Pairing Mechanism

Astarte streamlines a unified mechanism among transports for authenticating and authorizing devices through the use of SSL certificates and a certificate authority. It builds upon the [Mutual Authentication](https://en.wikipedia.org/wiki/Mutual_authentication) concept to make sure the identities of the endpoint and the client are well-known to each other.

## Authentication flow

![Pairing complete flow](assets/astarte_pairing_routine.svg)

*Side note: the Transport usually bears the public certificate of the CA, and actually interacts with the CA itself only if it exposes an OCSP endpoint and the transport is capable of understanding it. In case the CA exposes a CRL, the transport just makes sure to update its CRL from the CA every once in a while. In both cases, the Transport's only interaction with the CA is the configuration of its SSL endpoint.*

## Credentials Secret vs. Certificate

Each device is identified by a [Device ID](010-design_principles.html#device-id) and, on top of that, it has two different credentials directly associated to its ID: a Credentials Secret and a Certificate. Credentials Secret are a shared secret between Astarte and a device, which are used only in the Pairing routine. Each device has one Credentials Secret which remains valid throughout its whole lifecycle, and cannot be changed (unless operating manually).

A Certificate is an SSL Certificate emitted by a configured Certificate Authority (CA) orchestrated by Pairing. The certificate rotates depending on the emission policy of the CA and can be renewed and invalidated countless times over the device lifecycle. The certificate is a transient, asymmetric, device-specific, non-critical credential which can be in turn used to authenticate against the Transport(s).

Transports, by design, have no knowledge nor access to credentials or authentication details: they rather have to comply with the configured CA and the certificate parsing.

### Credentials Secret storage recommendations

As losing or disclosing a Credentials Secret might mean a device is compromised or requires manual intervention to be fixed and secured, storing it appropriately is critical.

Usually, when it comes to embedded devices, it is advised to store the Credentials Secret into an OTP, if available. Otherwise, storing it into the bootloader's variables is a viable and safe alternative. Other options might be having a separate, isolated storage containing the Credentials Secret. In general, Astarte SDK does not provide a streamlined mechanism for retrieving the Credentials Secret as the storage detail is strongly dependent on the target hardware - device developers should implement the safest strategy which better complies with their policies.

Tuning devices for security is out of the scope of this guide, however it is advised to make sure only the Astarte SDK has access to the Credentials Secret.

## Certificate Authority

Pairing is designed to interact with an abstract certificate authority, given this authority is capable of:

 * Emitting SSL Certificates with a custom CN (this is important in the transport authentication flow)
 * Revoking emitted certificates and exposing CRL/OCSP revocation information

and is accessible from a 3rd party (e.g. from a REST API). By default, Astarte supports [Cloudflare's CFSSL](https://github.com/cloudflare/cfssl), and also provides a minimal installation in its default deploy scripts. For bigger installations, especially in terms of number of connected devices, it is strongly advised to use a dedicated CFSSL installation. Also, [Astarte Enterprise](http://astarte.cloud/enterprise) provides a number of additional features including support for other external CAs.

## Certificate flow

During the Pairing flow, the device **must** generate autonomously a [Certificate Signing Request (CSR)](https://en.wikipedia.org/wiki/Certificate_signing_request) which will be in turn relayed by Pairing to the configured Certificate Authority. Pairing will also provide the Certificate Authority with a custom CN, which maps to `<realm>/<device id>`.

The CA **must** ensure the signed certificate carries this information, as it will be used by the transport to authenticate the caller inside Astarte. Pairing, in fact, will also perform sanity checks over the signed certificate and reject it in case the CA fails to comply.

## Agents

Agents are realm-level entities capable of registering a device into Astarte. Agents are a core concept in the Pairing mechanism, as no Device can perform the Pairing routine nor be authenticated against any transport unless an Agent previously gave its consent and delivered its Credentials Secret.

The recommended configuration includes an authenticated Agent in a trusted physical environment (e.g.: the distribution facility of the device) which guarantees an isolated and safe routine for generating Credentials Secret. However, such a setup might not always be possible, and Astarte's SDK has a "Fake Agent" concept to allow a simpler registration procedure.

### Fake Agent

In the fake agent use case, the device is preloaded with an "Agent Key", a shared secret which is **the same for every device in the realm**. This secret will be used only once, upon the device's first interaction with Astarte, and can be safely discarded afterwards. This approach largely simplifies the deploy procedure, but leaves every device with a secret which, if retrieved, can allow an entity to register an arbitrary Device in the realm.

If following the Fake Agent approach, it is advised to store the Agent Key in a safe area inside the device and delete it after retrieving a Credentials Secret (some OTPs allow this configuration).

## Transport responsibility

Once a device obtains a certificate, it is then capable of connecting to a transport. Transports have full responsibility in terms of authenticating the client, reporting and relaying its connection state to Astarte via its internal AMQP API. As such, it is fundamental that 3rd parties implementing new transports not only adhere to protocol specifications, but also make sure to implement the mutual authentication procedure meticolously, as a vulnerable transport acts as a single point of failure of the whole system, and is capable of bypassing the Pairing workflow entirely.

For this very reason, we encourage users to be extremely cautious when using 3rd party transports which have not been verified and hardly tested, especially when it comes to the client authentication stage.

## Pairing facilities

Pairing exposes an API which gives two additional facilities: first and foremost an `/info` endpoint which bears a set of information about both pairing itself and the transport the device should use or choose from. Moreover, it has a `/verify` endpoint where a client, authenticating with its Credentials Secret, can verify whether its certificate is valid or not. This is especially useful for checking against revocation lists.
