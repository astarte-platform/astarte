#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
  extends: [:astarte_rpc],
  import: [],
  mappings: [
    jwt_public_key_path: [
      commented: true,
      datatype: :binary,
      env_var: "HOUSEKEEPING_API_JWT_PUBLIC_KEY_PATH",
      doc: "The path to the public key used to verify the JWT auth.",
      default: "",
      hidden: false,
      to: "astarte_housekeeping_api.jwt_public_key_path"
    ],
    port: [
      commented: true,
      datatype: :integer,
      default: 4001,
      env_var: "HOUSEKEEPING_API_PORT",
      doc: "The port used from the Phoenix server.",
      hidden: false,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.http.port"
    ],
    bind_address: [
      commented: true,
      datatype: :binary,
      env_var: "HOUSEKEEPING_API_BIND_ADDRESS",
      doc: "The bind address for the Phoenix server.",
      default: "0.0.0.0",
      hidden: false,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.http.ip"
    ],
    disable_authentication: [
      commented: true,
      datatype: :atom,
      env_var: "HOUSEKEEPING_API_DISABLE_AUTHENTICATION",
      doc:
        "Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.",
      default: false,
      hidden: false,
      to: "astarte_housekeeping_api.disable_authentication"
    ],
    # Hidden options
    "astarte_housekeeping_api.namespace": [
      commented: false,
      datatype: :atom,
      default: Astarte.Housekeeping.API,
      doc: "Provide documentation for astarte_housekeeping_api.namespace here.",
      hidden: true,
      to: "astarte_housekeeping_api.namespace"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.url.host": [
      commented: false,
      datatype: :binary,
      default: "localhost",
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.url.host here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.url.host"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.secret_key_base": [
      commented: false,
      datatype: :binary,
      default: "Nxme5JSsvLykfa6sSoC+7cy9f3ycI8No2T1pwqFpB47KAt6tK/61jGpB+TIhNdjl",
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.secret_key_base here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.secret_key_base"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.view": [
      commented: false,
      datatype: :atom,
      default: Astarte.Housekeeping.APIWeb.ErrorView,
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.view here.",
      hidden: true,
      to:
        "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.view"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.accepts":
      [
        commented: false,
        datatype: [
          list: :binary
        ],
        default: [
          "json"
        ],
        doc:
          "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.accepts here.",
        hidden: true,
        to:
          "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.render_errors.accepts"
      ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.name": [
      commented: false,
      datatype: :atom,
      default: Astarte.Housekeeping.API.PubSub,
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.name here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.name"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.adapter": [
      commented: false,
      datatype: :atom,
      default: Phoenix.PubSub.PG2,
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.adapter here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.pubsub.adapter"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.server": [
      commented: false,
      datatype: :atom,
      default: true,
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.server here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.server"
    ],
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.version": [
      commented: false,
      datatype: :atom,
      doc:
        "Provide documentation for astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.version here.",
      hidden: true,
      to: "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.version"
    ]
  ],
  transforms: [
    "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.http.ip": fn conf ->
      [{_, ip}] =
        Conform.Conf.get(
          conf,
          "astarte_housekeeping_api.Elixir.Astarte.Housekeeping.APIWeb.Endpoint.http.ip"
        )

      charlist_ip = to_charlist(ip)

      case :inet.parse_address(charlist_ip) do
        {:ok, tuple_ip} -> tuple_ip
        _ -> raise "Invalid IP address in bind_address"
      end
    end,
    "astarte_housekeeping_api.jwt_public_key_pem": fn conf ->
      [{_, public_key_path}] =
        Conform.Conf.get(conf, "astarte_housekeeping_api.jwt_public_key_path")

      [{_, auth_disabled}] =
        Conform.Conf.get(conf, "astarte_housekeeping_api.disable_authentication")

      cond do
        auth_disabled ->
          ""

        public_key_path == "" ->
          raise "No JWT public key path configured"

        true ->
          File.read!(public_key_path)
      end
    end
  ],
  validators: []
]
