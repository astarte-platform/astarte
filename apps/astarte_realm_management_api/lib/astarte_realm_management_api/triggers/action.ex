#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Triggers.Action do
  @moduledoc """
  This module provides a wrapper for data held
  either in an Astarte.RealmManagement.API.Triggers.AMQPAction
  or in an Astarte.RealmManagement.API.Triggers.HttpAction struct.
  Validation is performed in the related modules.
  """
  use Ecto.Schema
  alias Astarte.RealmManagement.API.Triggers.Action

  @primary_key false
  embedded_schema do
    field :http_url, :string
    field :http_method, :string
    field :http_static_headers, {:map, :string}
    field :template, :string
    field :template_type, :string
    field :http_post_url, :string, virtual: true
    field :amqp_exchange, :string
    field :amqp_routing_key, :string
    field :amqp_static_headers, {:map, :string}
    field :amqp_message_expiration_ms, :integer
    field :amqp_message_priority, :integer
    field :amqp_message_persistent, :boolean
  end

  defimpl Jason.Encoder, for: Action do
    # HTTP actions must have the 'http_url' field set
    def encode(%Action{http_url: http_url} = action, opts) when not is_nil(http_url) do
      %Action{
        http_method: http_method,
        http_static_headers: http_static_headers,
        template: template,
        template_type: template_type
      } = action

      %{
        "http_url" => http_url,
        "http_method" => http_method
      }
      |> maybe_put("http_static_headers", http_static_headers)
      |> maybe_put("template", template)
      |> maybe_put("template_type", template_type)
      |> Jason.Encode.map(opts)
    end

    # AMQP actions must have the 'amqp_exchange' field set
    def encode(%Action{amqp_exchange: amqp_exchange} = action, opts)
        when not is_nil(amqp_exchange) do
      %Action{
        amqp_routing_key: amqp_routing_key,
        amqp_static_headers: amqp_headers,
        amqp_message_expiration_ms: amqp_message_expiration_ms,
        amqp_message_persistent: amqp_message_persistent,
        amqp_message_priority: amqp_message_priority
      } = action

      %{
        "amqp_exchange" => amqp_exchange,
        "amqp_routing_key" => amqp_routing_key,
        "amqp_message_expiration_ms" => amqp_message_expiration_ms,
        "amqp_message_persistent" => amqp_message_persistent
      }
      |> maybe_put("amqp_static_headers", amqp_headers)
      |> maybe_put("amqp_message_priority", amqp_message_priority)
      |> Jason.Encode.map(opts)
    end

    defp maybe_put(map, _key, nil),
      do: map

    defp maybe_put(map, key, value),
      do: Map.put(map, key, value)
  end
end
