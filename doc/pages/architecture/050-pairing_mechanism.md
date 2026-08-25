# Pairing Mechanism

Astarte's Pairing is a unified mechanism for [Registering Devices](035-register_device.html) and
obtaining _Transport Credentials_. Even though in Astarte each Transport is free to choose its own
Authentication mechanisms and Credentials autonomously, Pairing defines a well-known mechanism for
Registering Devices and for orchestrating the exchange of _Transport Credentials_. Pairing is the
main endpoint which orchestrates Device Authentication in Astarte, abstracting all details.

## Authentication flow

![Pairing basic flow](assets/astarte_basic_pairing_routine.svg)

## Credentials Secret vs. Transport Credentials

Each device is identified by a [Device ID](010-design_principles.html#device-id) and, on top of
that, it has two different credentials directly associated to its ID: _Credentials Secret_ and
_Transport Credentials_. _Credentials Secret_ is a shared secret between Astarte and a Device, which
are used only to authenticate against Pairing API. Each device has a single _Credentials Secret_
which remains valid throughout its whole lifecycle, and cannot be changed (unless operating
manually).

_Transport Credentials_ are Transport-specific credentials usually orchestrated by Pairing. Pairing
emits these Credentials through a policy which is usually imposed by the Authority emitting the
Credentials or by Pairing itself. They are designed to be transient, revokable and reasonably
short-lived - however, the actual behavior and their lifecycle is entirely orchestrated by the
Authority emitting them. The emission of _Transport Credentials_ can be inhibited for a specific
Device, you can read how to do that in the [User Guide](040-connect_device.html#credentials-secret-pairing-and-transports)

Transports, by design, have no knowledge nor access to _Credentials Secret_, but have full authority
over the authentication mechanism for devices. In fact, each Transport is free to choose the
authentication mechanism which fits it best.

### Credentials Secret storage recommendations

As losing or disclosing a _Credentials Secret_ might mean a device is compromised or requires manual
intervention to be fixed and secured, storing it appropriately is critical.

Usually, when it comes to embedded devices, it is advised to store the _Credentials Secret_ into an
OTP, if available. Otherwise, storing it into the bootloader's variables is a viable and safe
alternative. Other options might be having a separate, isolated storage containing _Credentials
Secret_. In general, Astarte SDK does not provide a streamlined mechanism for retrieving
_Credentials Secret_ as the storage detail is strongly dependent on the target hardware - device
developers should implement the safest strategy which better complies with their policies.

Tuning devices for security is out of the scope of this guide, however it is advised to make sure
only Astarte SDK has access to _Credentials Secret_.

## Using SSL Certificates as Transport Credentials

Whenever possible, Transports are advised to implement their Authentication through the use of SSL
certificates and a certificate authority by using [Mutual Authentication](https://en.wikipedia.org/wiki/Mutual_authentication), to ensure identities of the
endpoint and the client are well-known to each other - this is especially the case with Astarte's
MQTT Protocol on top of VerneMQ Transport.

In this case, _Transport Credentials_ are a SSL Certificate, and Pairing will interact with a
Certificate Authority. The certificate rotates depending on the emission policy of the CA and can be
renewed and invalidated countless times over the device lifecycle. The Certificate is a transient,
asymmetric, device-specific, non-critical Transport Credential which can be in turn used to
authenticate against the chosen Transport.

In this case, Transports should have no knowledge nor access to secrets or Authorization details:
they rather have to comply with the configured CA and the certificate parsing, as the Certificate
contains all needed information for Authorization as well.

### Mutual SSL Authentication Flow

![Pairing SSL flow](assets/astarte_ssl_pairing_routine.svg)

_Side note: the Transport usually bears the public certificate of the CA, and actually interacts
with the CA itself only if it exposes an OCSP endpoint and the Transport is capable of understanding
it. In case the CA exposes a CRL, the Transport just makes sure to update its CRL from the CA every
once in a while. In both cases, Transport's only interaction with the CA is the configuration of its
SSL endpoint._

### Certificate Authority

Pairing is designed to interact with an abstract certificate authority, given this authority is
capable of:

- Emitting SSL Certificates with a custom CN (this is important in the Transport authentication
  flow)
- Revoking emitted certificates and exposing CRL/OCSP revocation information

and is accessible from a 3rd party (e.g. from a REST API). By default, Astarte supports
[Cloudflare's CFSSL](https://github.com/cloudflare/cfssl), and also provides a minimal installation
in its default deploy scripts. For bigger installations, especially in terms of number of connected
devices, it is strongly advised to use a dedicated CFSSL installation. Also, [Astarte Enterprise](http://astarte.cloud/enterprise) provides a number of additional features including
support for other external CAs.

### Certificate flow

During the Pairing flow, the device **must** generate autonomously a [Certificate Signing Request (CSR)](https://en.wikipedia.org/wiki/Certificate_signing_request) which will be in turn relayed by
Pairing to the configured Certificate Authority. Pairing will also provide the Certificate Authority
with a custom CN, which maps to `<realm>/<device id>`.

The CA **must** ensure the signed certificate carries this information, as it will be used by the
Transport to authenticate the caller inside Astarte. Pairing, in fact, will also perform sanity
checks over the signed certificate and reject it in case the CA fails to comply.

## Agents

Agents are realm-level entities capable of registering a device into Astarte. Agents are a core
concept in the Pairing mechanism, as no Device can request its Transport Credentials nor be
authenticated against any Transport unless an Agent previously gave its consent and delivered its
_Credentials Secret_.

The recommended configuration includes an authenticated Agent in a trusted physical environment
(e.g.: the distribution facility of the device) which guarantees an isolated and safe routine for
generating _Credentials Secret_. However, such a setup might not always be possible, and Astarte's
SDK has an _On Board Agent_ concept to allow a simpler registration procedure.

### On Board Agent

In the _On Board Agent_ use case, the device is preloaded with an _Agent Key_, a shared secret which
is **not tied to a specific Device in the realm**. In fact, this secret is usually the same for all
Devices in the same realm.

This secret will be used only once, upon the device's first interaction with Astarte (Registration),
and can be safely discarded afterwards. This approach largely simplifies the deploy procedure, but
leaves every device with a secret which, if retrieved, can allow an entity to register an arbitrary
Device in the realm.

If following the _On Board Agent_ approach, it is advised to store the _Agent Key_ in a safe area
inside the device and delete it after retrieving a _Credentials Secret_ (some OTPs allow this
configuration).

## FIDO Device Onboarding

Since v1.4.0 devices can retrieve the _Credentials Secret_ through FIDO Device Onboarding
([FDO overview]) protocol. The procedures described in FDO specification ([FDO 1.1]) allow
establishing a chain of trust from the device manufacturer to the final owner, who can claim
ownership of the device through an _Owner Onboarding Service_ (Astarte Pairing service). When
registering a device via FDO, it will be provisioned with all the data needed for further
communications with Astarte.

The main information transfer artifact in FDO procedures is the _Ownership Voucher_, a structured
digital document that links the Manufacturer with the Owner through a chain of signed public keys.
Each signature of a public key authorizes the possessor of the corresponding private key to take
ownership of the device or pass ownership through another link in the chain: every time the device
changes hands in the supply chain (e.g. from manufacturer to reseller to final owner),
the previous owner signs the public key of the new owner and adds it to the voucher, with the last
public key of the voucher being the _Owner Key_. The voucher also includes the device public key
and the GUID assigned to it during initialization, allowing for device identification and authentication.
The voucher corresponding to a specific device must be uploaded into the Astarte platform to start
the device registration flow.

The initial setup of the device is carried out through _Device Initialization_ (DI) procedures at
the manufacturer's site, pre-loading into the device a set of secrets and the URL of a
_Rendezvous Server_ (an intermediary node allowing devices to find a suitable owner onboarding platform).
Astarte expects an external _Rendezvous Server_ to be available and properly configured.
FDO registration makes it possible to initialize a device without it being aware of its
destination realm and final owner.

### Transfer Ownership protocols

_Transfer Ownership_ protocols detail specific subsequent phases enabling the effective onboarding
of the device onto its reference platform. Astarte implements the TO0 and TO2 protocols.

TO0 and TO2 communications are carried out only over HTTP/HTTPS transport in the current implementation.
The URL which the device must use to initiate the TO2 protocol is in the form
_<ASTARTE_REALM>.api.<ASTARTE_BASE_URL>/<FDO_URL>_; this is currently necessary to map the device
session to the correct realm.

#### TO0 Protocol

TO0 messaging is started as soon as a new _Ownership Voucher_ is uploaded onto the platform by the
final user. In this phase Astarte notifies the configured _Rendezvous Server_ that it is the expected
platform to handle the onboarding of the device corresponding to the GUID contained in the voucher.
This allows the device to discover its reference onboarding platform.

#### TO2 protocol

Through TO2 protocol the device and Astarte directly communicate with each other in order to
mutually authenticate and establish a secure tunnel through which the device receives its
credentials secret along with optional additional configurations.

For mutual authentication to work Astarte needs access to the private key of the final device owner,
which is pre-loaded onto an external secure vault (see section [Owner Keys management](#owner-keys-management)
for details); this key must correspond to the owner public key contained in the voucher. The
procedure of extending the voucher with the owner key is out of scope for the Astarte implementation
of FDO.

The _TO2.SetupDevice_ message is used to send device configurations to overwrite the pre-existing
ones, in order to complete the ownership transfer and tie the device to the new owner. These changes
are applied only after the entire TO2 procedure is completed. If these configurations are not
explicitly passed by the user, they will be derived from the data contained in the voucher.

The supported replacement parameters are:

- _Replacement GUID_, a GUID to be assigned to the device
- _Replacement Rendezvous Info_, a set of connection instructions to direct the device to the
  RV server for any future FDO procedures
- _Replacement Owner Public Key_, to claim the current final owner as the trusted entity for any
  future ownership transfers

The _TO2.DeviceServiceInfo_ message(s) shall be used by the device to send variables and commands
to Astarte. Notably, this mechanism can be used to determine how the device will be identified
upon registration. If the device provides its serial number using the _devmod:sn_ field,
Astarte will use that value to generate the _device ID_. If this key is omitted, Astarte will
automatically generate an ID using its standard generator.

The _TO2.OwnerServiceInfo_ message(s) shall be used to send a list of variables or commands
from Astarte to the device. In the current implementation the following variables are sent
to the device:

- _astarte:active_: set to 'true'
- _astarte:realm_: the name of the realm to which the device is registered
- _astarte:secret_: the credentials secret
- _astarte:baseurl_: the Astarte base URL
- _astarte:deviceid_: the encoded device ID

### Owner Keys management

Astarte must be able to sign TO2 messages using the owner private key in order to complete the
Transfer Ownership protocol.
A HashiCorp Vault / OpenBao service reachable by Astarte (referred to as "the vault" for the rest of
the document) is used as a safe storage for owner keys, and messages are signed directly
by it without keys ever being downloaded (or even known) by Astarte.
Astarte internally correlates each uploaded voucher with an owner key pre-loaded into the vault.

In order to import owner keys into the vault, it is possible to

- upload a private key to Astarte, which is then imported ino the vault and immediately forgotten, or
- have the vault generate a keypair and return the related public key, which can then be used
  to extend the Ownership Voucher to account for the final owner

The vault allows for full separation of resources pertaining to different realms leveraging
its internal namespace structure.

## Transport responsibility

Once a device obtains its _Transport Credentials_, it is then capable of connecting to the Transport
the credentials were forged for. Transports have full responsibility in terms of authenticating the
client, reporting and relaying its connection state to Astarte via its internal AMQP API. As such,
it is fundamental that 3rd parties implementing new Transports not only adhere to protocol
specifications, but also make sure to implement the authentication procedure meticolously, as a
vulnerable Transport acts as a single point of failure of the whole system, and is capable of
bypassing the Pairing workflow entirely.

For this very reason, we encourage users to be extremely cautious when using 3rd party Transports
which have not been verified and hardly tested, especially when it comes to the Client
Authentication stage.

Even though there are valid use cases where Mutual Authentication is not usable, Transports are
advised to stick to Mutual SSL Authentication where possible. This, among other benefits, allows to
use Pairing's core features for handling SSL Certificates.

## Pairing facilities

Pairing's Device API exposes two additional facilities: first and foremost an endpoint which bears a
set of information about both Pairing itself and Transports the device should use or choose from.
This endpoint is Device and Realm specific and can be found at
[`/{realm_name}/devices/{hw_id}`](api/index.html?urls.primaryName=Pairing%20API#/device/getInfo).
This allows granting each Device a specific Transport configuration, which can be useful in
installations with more than a single Transport, and automates the configuration on the Device's
end, which knows in advance what is supported and how to access its Transport(s).

Moreover, each Transport implementation has a `/verify` endpoint where a client, authenticating with
its _Credentials Secret_, can verify whether its _Transport Credentials_ are valid or not. This, in
case SSL is used, is especially useful for checking against revocation lists.

[FDO overview]: https://fidoalliance.org/device-onboarding-overview/
[FDO 1.1]: https://fidoalliance.org/specs/FDO/FIDO-Device-Onboard-PS-v1.1-20220419/FIDO-Device-Onboard-PS-v1.1-20220419.pdf
