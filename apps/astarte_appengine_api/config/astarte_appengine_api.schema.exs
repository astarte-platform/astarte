@moduledoc """
A schema is a keyword list which represents how to map, transform, and validate
configuration values parsed from the .conf file. The following is an explanation of
each key in the schema definition in order of appearance, and how to use them.

## Import

A list of application names (as atoms), which represent apps to load modules from
which you can then reference in your schema definition. This is how you import your
own custom Validator/Transform modules, or general utility modules for use in
validator/transform functions in the schema. For example, if you have an application
`:foo` which contains a custom Transform module, you would add it to your schema like so:

`[ import: [:foo], ..., transforms: ["myapp.some.setting": MyApp.SomeTransform]]`

## Extends

A list of application names (as atoms), which contain schemas that you want to extend
with this schema. By extending a schema, you effectively re-use definitions in the
extended schema. You may also override definitions from the extended schema by redefining them
in the extending schema. You use `:extends` like so:

`[ extends: [:foo], ... ]`

## Mappings

Mappings define how to interpret settings in the .conf when they are translated to
runtime configuration. They also define how the .conf will be generated, things like
documention, @see references, example values, etc.

See the moduledoc for `Conform.Schema.Mapping` for more details.

## Transforms

Transforms are custom functions which are executed to build the value which will be
stored at the path defined by the key. Transforms have access to the current config
state via the `Conform.Conf` module, and can use that to build complex configuration
from a combination of other config values.

See the moduledoc for `Conform.Schema.Transform` for more details and examples.

## Validators

Validators are simple functions which take two arguments, the value to be validated,
and arguments provided to the validator (used only by custom validators). A validator
checks the value, and returns `:ok` if it is valid, `{:warn, message}` if it is valid,
but should be brought to the users attention, or `{:error, message}` if it is invalid.

See the moduledoc for `Conform.Schema.Validator` for more details and examples.
"""
[
  extends: [:astarte_data_access, :astarte_rpc],
  import: [],
  mappings: [
    "max_results_limit": [
      commented: true,
      datatype: :integer,
      default: 10000,
      env_var: "APPENGINE_MAX_RESULTS_LIMIT",
      doc: "The max number of data points returned by AppEngine API with a single call. Defaults to 10000. If <= 0, results are unlimited.",
      hidden: false,
      to: "astarte_appengine_api.max_results_limit"
    ],
    "astarte_appengine_api.mqtt_options.username": [
      commented: true,
      datatype: :binary,
      default: "test",
      env_var: "APPENGINE_API_MQTT_USERNAME",
      doc: "Provide documentation for astarte_appengine_api.mqtt_options.username here.",
      hidden: false,
      to: "astarte_appengine_api.mqtt_options.username"
    ],
    "astarte_appengine_api.mqtt_options.password": [
      commented: true,
      datatype: :binary,
      default: "test",
      env_var: "APPENGINE_API_MQTT_PASSWORD",
      doc: "Provide documentation for astarte_appengine_api.mqtt_options.password here.",
      hidden: false,
      to: "astarte_appengine_api.mqtt_options.password"
    ],
    "astarte_appengine_api.mqtt_options.host": [
      commented: true,
      datatype: :binary,
      default: "localhost",
      env_var: "APPENGINE_API_MQTT_HOST",
      doc: "Provide documentation for astarte_appengine_api.mqtt_options.host here.",
      hidden: false,
      to: "astarte_appengine_api.mqtt_options.host"
    ],
    "astarte_appengine_api.mqtt_options.port": [
      commented: true,
      datatype: :integer,
      default: 1883,
      env_var: "APPENGINE_API_MQTT_PORT",
      doc: "Provide documentation for astarte_appengine_api.mqtt_options.port here.",
      hidden: false,
      to: "astarte_appengine_api.mqtt_options.port"
    ],
    "port": [
      commented: true,
      datatype: :integer,
      default: 4002,
      env_var: "APPENGINE_API_PORT",
      doc: "The port used by the Phoenix server.",
      hidden: false,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.http.port"
    ],
    "rooms_amqp_client_options.host": [
      commented: true,
      datatype: :binary,
      default: "localhost",
      env_var: "APPENGINE_API_ROOMS_AMQP_CLIENT_HOST",
      doc: "The host for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_appengine_api.rooms_amqp_client_options.host"
    ],
    "rooms_amqp_client_options.username": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "APPENGINE_API_ROOMS_AMQP_CLIENT_USERNAME",
      doc: "The username for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_appengine_api.rooms_amqp_client_options.username"
    ],
    "rooms_amqp_client_options.password": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "APPENGINE_API_ROOMS_AMQP_CLIENT_PASSWORD",
      doc: "The password for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_appengine_api.rooms_amqp_client_options.password"
    ],
    "rooms_amqp_client_options.virtual_host": [
      commented: true,
      datatype: :binary,
      default: "/",
      env_var: "APPENGINE_API_ROOMS_AMQP_CLIENT_VIRTUAL_HOST",
      doc: "The virtual_host for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_appengine_api.rooms_amqp_client_options.virtual_host"
    ],
    "rooms_amqp_client_options.port": [
      commented: true,
      datatype: :integer,
      default: 5672,
      env_var: "APPENGINE_API_ROOMS_AMQP_CLIENT_PORT",
      doc: "The port for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_appengine_api.rooms_amqp_client_options.port"
    ],
    "bind_address": [
      commented: true,
      datatype: :binary,
      env_var: "APPENGINE_API_BIND_ADDRESS",
      doc: "The bind address for the Phoenix server.",
      default: "0.0.0.0",
      hidden: false,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.http.ip"
    ],
    "disable_authentication": [
      commented: true,
      datatype: :atom,
      env_var: "APPENGINE_API_DISABLE_AUTHENTICATION",
      doc: "Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.",
      default: false,
      hidden: false,
      to: "astarte_appengine_api.disable_authentication"
    ],
    "swagger_ui": [
      commented: true,
      datatype: :boolean,
      default: true,
      env_var: "SWAGGER_UI",
      doc: "Whether to install Swagger UI and expose API documentation on /swagger.",
      hidden: false,
      to: "astarte_appengine_api.swagger_ui"
    ],
    # Hidden options
    "astarte_appengine_api.namespace": [
      commented: false,
      datatype: :atom,
      default: Astarte.AppEngine.API,
      doc: "Provide documentation for astarte_appengine_api.namespace here.",
      hidden: true,
      to: "astarte_appengine_api.namespace"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.url.host": [
      commented: false,
      datatype: :binary,
      default: "localhost",
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.url.host here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.url.host"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.secret_key_base": [
      commented: false,
      datatype: :binary,
      default: "oLTSqHyMVoBtu3Gu504Dn6HFN1qdFXtkJ0yFViRDbXckOHgTjFs1XaRS0QaKZ8KL",
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.secret_key_base here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.secret_key_base"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.view": [
      commented: false,
      datatype: :atom,
      default: Astarte.AppEngine.APIWeb.ErrorView,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.view here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.view"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.accepts": [
      commented: false,
      datatype: [
        list: :binary
      ],
      default: [
        "json"
      ],
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.accepts here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.render_errors.accepts"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.name": [
      commented: false,
      datatype: :atom,
      default: Astarte.AppEngine.API.PubSub,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.name here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.name"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.adapter": [
      commented: false,
      datatype: :atom,
      default: Phoenix.PubSub.PG2,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.adapter here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.pubsub.adapter"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.debug_errors": [
      commented: false,
      datatype: :atom,
      default: true,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.debug_errors here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.debug_errors"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.code_reloader": [
      commented: false,
      datatype: :atom,
      default: true,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.code_reloader here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.code_reloader"
    ],
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.check_origin": [
      commented: false,
      datatype: :atom,
      default: false,
      doc: "Provide documentation for astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.check_origin here.",
      hidden: true,
      to: "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.check_origin"
    ],
    "logger.console.metadata": [
      commented: false,
      datatype: [
        list: :atom
      ],
      default: [
        :request_id
      ],
      doc: "Provide documentation for logger.console.metadata here.",
      hidden: true,
      to: "logger.console.metadata"
    ],
    "logger.console.format": [
      commented: false,
      datatype: :binary,
      default: """
      [$level] $message
      """,
      doc: "Provide documentation for logger.console.format here.",
      hidden: true,
      to: "logger.console.format"
    ],
    "phoenix.stacktrace_depth": [
      commented: false,
      datatype: :integer,
      default: 20,
      doc: "Provide documentation for phoenix.stacktrace_depth here.",
      hidden: true,
      to: "phoenix.stacktrace_depth"
    ]
  ],
  transforms: [
    "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.http.ip": fn conf ->
      [{_, ip}] = Conform.Conf.get(conf, "astarte_appengine_api.Elixir.Astarte.AppEngine.APIWeb.Endpoint.http.ip")

      charlist_ip = to_charlist(ip)

      case :inet.parse_address(charlist_ip) do
        {:ok, tuple_ip} -> tuple_ip
        _ -> raise "Invalid IP address in bind_address"
      end
    end,
    "astarte_appengine_api.max_results_limit": fn conf ->
      [{_, results}] = Conform.Conf.get(conf, "astarte_appengine_api.max_results_limit")

      if results > 0 do
        results
      else
        # If <= 0 we fix it to 0 to indicate no limit
        0
      end
    end
  ],
  validators: []
]
