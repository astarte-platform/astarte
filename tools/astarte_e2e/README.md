# AstarteE2E

AstarteE2E is employed as a monitoring tool with the following functions:

- Astarte Device Simulation: AstarteE2E is responsible for simulating an Astarte device, allowing it to register with the Astarte system and stream data.

- Astarte Client Functionality: AstarteE2E also acts as an Astarte client that can receive data through triggers from the Astarte system.

- Data Consistency: The primary objective of AstarteE2E is to compare the data sent by the virtual device it simulates with the data received through triggers. This comparison helps determine the consistency of data.

- Cluster Status Evaluation: If the data received via triggers matches the data sent by the virtual device, it is considered an indicator that the cluster's status is in good condition.

- Error Notification: AstarteE2E has the capability to detect and respond to errors, such as device disconnections or other issues within the Astarte system. In the event of an error, AstarteE2E can send notifications to a designated audience via email. This serves as an alert mechanism, allowing relevant individuals to become aware of potential issues with the Astarte system.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `astarte_e2e` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:astarte_e2e, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/astarte_e2e](https://hexdocs.pm/astarte_e2e).

## Environment variables

| Environment                | Required | Default | Description                                                                                                                                                                                                   |
| -------------------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| E2E_PAIRING_URL            | &check;  | None    | URL of the Astarte pairing service, e.g. https://api.astarte.example.com/pairing                                                                                                                              |
| E2E_DEVICE_ID              | &check;  | None    | An Astarte device ID, which is a valid UUID encoded with standard Astarte device_id encoding (Base64 url encoding, no padding).                                                                               |
| E2E_CREDENTIALS_SECRET     | &check;  | None    | Astarte Credentials Secret for the given device ID. You can generate one with `$ astartectl pairing agent register <device_id>.`                                                                              |
| E2E_IGNORE_SSL_ERRORS      | &check;  | false   | Whether the e2e test should ignore SSL errors when connecting to Astarte.                                                                                                                                     |
| E2E_APPENGINE_URL          | &check;  | None    | URL of the Astarte AppEngine service, e.g. https://api.astarte.example.com/appengine                                                                                                                          |
| E2E_REALM_MANAGEMENT_URL   | &check;  | None    | URL of the Astarte Realm Management service, e.g. https://api.astarte.example.com/realmmanagement                                                                                                             |
| E2E_REALM                  | &check;  | None    | Realm name.                                                                                                                                                                                                   |
| E2E_JWT                    | &check;  | None    | The Astarte JWT employed to access Astarte APIs. It should have at least claims for Pairing and AppEngine. The token can be generated with: `$ astartectl utils gen-jwt <service> -k <your-private-key>.pem`. |
| E2E_CHECK_INTERVAL_SECONDS | &cross;  | 60      | Time interval between consecutive checks (in seconds).                                                                                                                                                        |
| E2E_PORT                   | &cross;  | 4010    | The port used to expose AstarteE2E's metrics. Defaults to 4010.                                                                                                                                               |
| E2E_CHECK_REPETITIONS      | &cross;  | None    | Overall number of consistency checks repetitions. Defaults to 0, corresponding to infinite checks.                                                                                                            |
| E2E_CLIENT_TIMEOUT_SECONDS | &cross;  | 10      | The amount of time (in seconds) the websocket client is allowed to wait for an incoming message. Defaults to 10 seconds.                                                                                      |
| E2E_CLIENT_MAX_TIMEOUTS    | &cross;  | 10      | The maximum number of consecutive timeouts before the websocket client is allowed to crash. Defaults to 10.                                                                                                   |
| E2E_FAILURES_BEFORE_ALERT  | &cross;  | 10      | The number of consecutive failures before an email alert is sent. Defaults to 10.                                                                                                                             |
| E2E_MAIL_TO_ADDRESS        | &cross;  | None    | The comma-separated email recipients.                                                                                                                                                                         |
| E2E_MAIL_FROM_ADDRESS      | &cross;  | None    | The notification email sender.                                                                                                                                                                                |
| E2E_MAIL_SUBJECT           | &check;  | None    | The subject of the notification email.                                                                                                                                                                        |
| E2E_MAIL_API_KEY           | &cross;  | None    | The mail service's API key. This env var must be set and valid to use the mail service.                                                                                                                       |
| E2E_MAIL_DOMAIN            | &cross;  | None    | The mail domain. This env var must be set and valid to use the mailgun service.                                                                                                                               |
| E2E_MAIL_API_BASE_URI      | &cross;  | None    | The mail API base URI. This env var must be set and valid to use the mail service.                                                                                                                            |
| E2E_MAIL_SERVICE           | &cross;  | None    | The mail service. Currently only "mailgun" and "sendgrid" are supported. This env var must be set and valid to use the mail service.                                                                          |

### Required Environment before runing project

```bash
export  E2E_DEVICE_ID="Device ID"
export  E2E_PAIRING_URL="Paring URL"
export  E2E_CREDENTIALS_SECRET="astartectl pairing agent register <device_id>"
export  E2E_IGNORE_SSL_ERRORS="true"
export  E2E_APPENGINE_URL="Appengine URL"
export  E2E_REALM="Realm name"
export  E2E_JWT="astartectl utils gen-jwt <service> -k <your-private-key>.pem"
export  E2E_MAIL_SUBJECT="Message"
```

## Astarte Interfaces

### You'll need to install these two interfaces before running Astarte E2E.

```json
{
  "interface_name": "org.astarte-platform.e2etest.SimpleDatastream",
  "version_major": 1,
  "version_minor": 0,
  "type": "datastream",
  "ownership": "device",
  "description": "SimpleDatastream allows to stream custom strings. Each string is employed to assess the end to end functionality of Astarte.",
  "mappings": [
    {
      "endpoint": "/correlationId",
      "type": "string",
      "database_retention_policy": "use_ttl",
      "database_retention_ttl": 86400,
      "description": "Each correlationId persists into the database for a predefined amount of time as to avoid an unbounded collection of entries."
    }
  ]
}
```

```json
{
  "interface_name": "org.astarte-platform.e2etest.SimpleProperties",
  "version_major": 1,
  "version_minor": 0,
  "type": "properties",
  "ownership": "device",
  "description": "SimpleProperties allows to send custom strings. Each string is employed to assess the end to end functionality of Astarte.",
  "mappings": [
    {
      "endpoint": "/correlationId",
      "type": "string"
    }
  ]
}
```
