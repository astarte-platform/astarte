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
  extends: [:astarte_data_access],
  import: [],
  mappings: [
    "amqp_consumer_options.host": [
      commented: true,
      datatype: :binary,
      default: "localhost",
      env_var: "TRIGGER_ENGINE_AMQP_CONSUMER_HOST",
      doc: "Host for the AMQP consumer connection",
      hidden: false,
      to: "astarte_trigger_engine.amqp_consumer_options.host"
    ],
    "amqp_consumer_options.port": [
      commented: true,
      datatype: :integer,
      default: 5672,
      env_var: "TRIGGER_ENGINE_AMQP_CONSUMER_PORT",
      doc: "Port for the AMQP consumer connection",
      hidden: false,
      to: "astarte_trigger_engine.amqp_consumer_options.port"
    ],
    "amqp_consumer_options.username": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "TRIGGER_ENGINE_AMQP_CONSUMER_USERNAME",
      doc: "Username for the AMQP consumer connection",
      hidden: false,
      to: "astarte_trigger_engine.amqp_consumer_options.username"
    ],
    "amqp_consumer_options.password": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "TRIGGER_ENGINE_AMQP_CONSUMER_PASSWORD",
      doc: "Password for the AMQP consumer connection",
      hidden: false,
      to: "astarte_trigger_engine.amqp_consumer_options.password"
    ],
    "amqp_consumer_options.virtual_host": [
      commented: true,
      datatype: :binary,
      default: "/",
      env_var: "TRIGGER_ENGINE_AMQP_CONSUMER_VIRTUAL_HOST",
      doc: "Virtual host for the AMQP consumer connection",
      hidden: false,
      to: "astarte_trigger_engine.amqp_consumer_options.virtual_host"
    ],
    "amqp_events_queue_name": [
      commented: true,
      datatype: :binary,
      default: "astarte_events",
      env_var: "TRIGGER_ENGINE_AMQP_EVENTS_QUEUE_NAME",
      doc: "The name of the AMQP queue created by the events consumer",
      hidden: false,
      to: "astarte_trigger_engine.amqp_events_queue_name"
    ],
    "amqp_events_exchange_name": [
      commented: true,
      datatype: :binary,
      default: "astarte_events",
      env_var: "TRIGGER_ENGINE_AMQP_EVENTS_EXCHANGE_NAME",
      doc: "The name of the exchange on which events are published",
      hidden: false,
      to: "astarte_trigger_engine.amqp_events_exchange_name"
    ],
    "amqp_events_routing_key": [
      commented: true,
      datatype: :binary,
      default: "trigger_engine",
      env_var: "TRIGGER_ENGINE_AMQP_EVENTS_ROUTING_KEY",
      doc: "The routing_key used to bind to TriggerEngine specific events",
      hidden: false,
      to: "astarte_trigger_engine.amqp_events_routing_key"
    ]
  ],
  transforms: [],
  validators: []
]
