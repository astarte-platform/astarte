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
    "amqp_consumer_options.host": [
      commented: true,
      datatype: :binary,
      default: "localhost",
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_HOST",
      doc: "The host for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_options.host"
    ],
    "amqp_consumer_options.username": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_USERNAME",
      doc: "The username for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_options.username"
    ],
    "amqp_consumer_options.password": [
      commented: true,
      datatype: :binary,
      default: "guest",
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PASSWORD",
      doc: "The password for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_options.password"
    ],
    "amqp_consumer_options.virtual_host": [
      commented: true,
      datatype: :binary,
      default: "/",
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_VIRTUAL_HOST",
      doc: "The virtual_host for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_options.virtual_host"
    ],
    "amqp_consumer_options.port": [
      commented: true,
      datatype: :integer,
      default: 5672,
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PORT",
      doc: "The port for the AMQP consumer connection.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_options.port"
    ],
    "amqp_producer_options.host": [
      commented: true,
      datatype: :binary,
      required: false,
      env_var: "DATA_UPDATER_PLANT_AMQP_PRODUCER_HOST",
      doc:
        "The host for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_producer_options.host"
    ],
    "amqp_producer_options.username": [
      commented: true,
      datatype: :binary,
      required: false,
      env_var: "DATA_UPDATER_PLANT_AMQP_PRODUCER_USERNAME",
      doc:
        "The username for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_producer_options.username"
    ],
    "amqp_producer_options.password": [
      commented: true,
      datatype: :binary,
      required: false,
      env_var: "DATA_UPDATER_PLANT_AMQP_PRODUCER_PASSWORD",
      doc:
        "The password for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_producer_options.password"
    ],
    "amqp_producer_options.virtual_host": [
      commented: true,
      datatype: :binary,
      required: false,
      env_var: "DATA_UPDATER_PLANT_AMQP_PRODUCER_VIRTUAL_HOST",
      doc:
        "The virtual_host for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_producer_options.virtual_host"
    ],
    "amqp_producer_options.port": [
      commented: true,
      datatype: :integer,
      required: false,
      env_var: "DATA_UPDATER_PLANT_AMQP_PRODUCER_PORT",
      doc:
        "The port for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_producer_options.port"
    ],
    amqp_events_exchange_name: [
      commented: true,
      datatype: :binary,
      default: "astarte_events",
      env_var: "DATA_UPDATER_PLANT_AMQP_EVENTS_EXCHANGE_NAME",
      doc: "The exchange used by the AMQP producer to publish events.",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_events_exchange_name"
    ],
    data_queue_prefix: [
      commented: true,
      datatype: :binary,
      required: false,
      default: "astarte_data_",
      env_var: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_PREFIX",
      doc: "The prefix used to contruct data queue names, together with queue indexes.",
      hidden: false,
      to: "astarte_data_updater_plant.data_queue_prefix"
    ],
    data_queue_range_start: [
      commented: true,
      datatype: :integer,
      required: false,
      default: 0,
      env_var: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_RANGE_START",
      doc: "The first queue index that is handled by this Data Updater Plant instance",
      hidden: false,
      to: "astarte_data_updater_plant.data_queue_range_start"
    ],
    data_queue_range_start: [
      commented: true,
      datatype: :integer,
      required: false,
      default: 1,
      env_var: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_TOTAL_COUNT",
      doc:
        "Returns the total number of data queues in the whole Astarte cluster. This should have the same value of DATA_QUEUE_COUNT in the VerneMQ plugin",
      hidden: false,
      to: "astarte_data_updater_plant.data_queue_total_count"
    ],
    data_queue_range_end: [
      commented: true,
      datatype: :integer,
      required: false,
      default: 0,
      env_var: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_RANGE_END",
      doc: "The last queue index that is handled by this Data Updater Plant instance",
      hidden: false,
      to: "astarte_data_updater_plant.data_queue_range_end"
    ],
    "amqp_consumer.prefetch_count": [
      commented: true,
      datatype: :integer,
      default: 300,
      env_var: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PREFETCH_COUNT",
      doc:
        "The prefetch count of the AMQP consumer connection. A prefetch count of 0 means unlimited (not recommended).",
      hidden: false,
      to: "astarte_data_updater_plant.amqp_consumer_prefetch_count"
    ]
  ],
  transforms: [
    "astarte_data_updater_plant.amqp_producer_options":
      Astarte.DataUpdaterPlant.Config.AMQPProducerTransform
  ],
  validators: []
]
