# Astarte Dashboard

Astarte Dashboard is a web UI that allows visualizing the status of your realm
and to perform administrative tasks such as installing interfaces and triggers,
managing devices, pipelines and flows.

[![Dashboard Home Screen Shot][dashboard-home-screenshot]](https://github.com/davidebriani/astarte/blob/docs/add-astarte-dashboard-documentation/doc/images/astarte-dashboard-realm-overview.png)

## Table of Contents

- [Try it!](#try-it)
- [Run it locally](#run-it-locally)
  - [Prerequisites](#prerequisites)
  - [Configuration](#configuration)
  - [Run it](#run-it)
- [Contributing](#contributing)
  - [Dependencies](#dependencies)
  - [Starting up a local server](#starting-up-a-local-server)
  - [Testing](#testing)
- [License](#license)


## Try it!

Astarte Dashboard is deployed by default on all Astarte instances.

When deploying locally using __docker-compose__, visit http://localhost:4040.

On a __kubernetes__ cluster, the URL is specified in the [Astarte Voyager Ingress configuration](https://docs.astarte-platform.org/snapshot/065-setup_ingress.html#creating-an-astartevoyageringress).

Or try out __Astarte as a service__ on [Astarte Cloud](https://console.astarte.cloud/).

## Run it locally

### Prerequisites

Before starting you must have:

- [Docker](https://docs.docker.com/get-docker/) version 19.0 or greater.
- An Astarte instance up and running, either locally or on a remote cluster.
  You can have a look at [Astarte in 5 minutes](https://docs.astarte-platform.org/1.0/010-astarte_in_5_minutes.html#content)
  if you haven't already.

### Configuration

Astarte Dashboard relies on a configuration file for parameters like the Astarte API URL.
As soon as you open Astarte Dashboard, it will search for a file `config.json`
containing the following keys:

* __astarte_api_url__ (required):
  the base URL of your Astarte API endpoints.
  This will be used to deduct the endpoints of all Astarte components:

  + AppEngine: api_url + /appengine
  + Realm Management: api_url + /realmmanagement
  + Pairing: api_url + /pairing
  + Flow: api_url + /flow

  The special string `localhost` sets the enpoints the one ones used in the Astarte in 5 minutes guide

  + AppEngine: `http://localhost:4002`
  + Realm Management: `http://localhost:4000`
  + Pairing: `http://localhost:4003`
  + Flow: `http://localhost:4009`

  In custom deployments those URLs may change, so you can overwrite any of those
  with the following optional keys:
  + __realm_management_url__
  + __appengine_url__
  + __pairing_url__
  + __flow_url__

* __default_realm__ (optional):
  the default realm to login into.

* __enable_flow_preview__ (optional):
  this requires your Astarte cluster to have Flow configured and running.
  When enabled (set it to `true`) the Dashboard will display Flow API status
  and the related pages such as flows, pipelines and blocks.

* __auth__ (required):
  the list of auth options available for login.

  Supported authentication methods are direct token or OAuth2 Implicit Grant

  + __oauth__:
    following the OAuth standard, Astarte Dashboard will redirect you to your OAuth provider
    for login. On successful login you'll be redirected back to Astarte Dashboard.

  + __token__:
    A token is needed to authenticate against the Astarte API.
    You can generate one from the realm private key using [astartectl](https://github.com/astarte-platform/astartectl).

  If multiple auth options are enabled, the user may use either one.

* __default_auth__ (required):
  the default auth option to display when attempting login.


An example config would look like this:
```json
{
  "astarte_api_url": "https://api.example.com",
  "enable_flow_preview": true,
  "default_realm": "myrealm",
  "default_auth": "token",
  "auth": [
    {
      "type": "token"
    },
    {
      "type": "oauth",
      "oauth_api_url": "https://auth.example.com"
    }
  ]
}
```

### Run it

You can easily run the Astarte Dashboard using the official Docker images from the public
Dockerhub registry.

For example, to run it locally on port 4040, you can use the following command:

```sh
docker run \
  -p 4040:80 \
  -v /absolute/path/to/config.json:/usr/share/nginx/html/user-config/config.json \
  astarte/astarte-dashboard:1.0.2
```


## Contributing

### Dependencies

Astarte Dashboard is written in TypeScript using the React framework and npm to manage dependencies.

* node (10 or greater)
* npm (6 or greater)

### Starting up a local server

1. Clone this repo locally
   ```sh
   git clone git@github.com:astarte-platform/astarte-dashboard.git && cd astarte-dashboard
   ```
2. Install the project dependencies
   ```sh
   npm install
   ```
3. Place your configuration file in `src/user-config/config.json`
4. Start the dev server
   ```sh
   npm run start
   ```
5. Open the browser at the displayed URL, usually `http://localhost:8080`


### Testing

Tests are carried out using Cypress, which in turn uses a headless browser to simulate user interactions.
So before testing, a server from which the browser can access Astarte Dashboard is needed.
The command `start-ci` serves the purpose.
```sh
npm run start-ci
```

Once the server is up, you can run tests in the CLI by running the command `test`
```sh
npm run test
```

But if you want to test specific pages or components, you can open the Cypress GUI with
```sh
npm run cypress:open
```

Other routine tests are formatting and typescript checks
```sh
 npm run check-format
 npm run check-types
```

## License

Distributed under the Apache2.0 License. See [LICENSE](LICENSE) for more information.


<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[dashboard-home-screenshot]: https://github.com/astarte-platform/astarte/blob/v1.0.2/doc/images/astarte-dashboard-realm-overview.png
