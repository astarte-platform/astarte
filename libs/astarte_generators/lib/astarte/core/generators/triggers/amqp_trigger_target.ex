#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Triggers.AMQPTriggerTarget do
  @moduledoc """
  Generates AMQP trigger targets.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Common.Generators.UUID

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  @amqp_name_chars [?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?., ?:]

  @doc """
  Generates an AMQP trigger target with valid AMQP delivery options.
  """
  @spec amqp_trigger_target() :: StreamData.t(AMQPTriggerTarget.t())
  @spec amqp_trigger_target(params :: keyword()) :: StreamData.t(AMQPTriggerTarget.t())
  def amqp_trigger_target(params \\ []) do
    params gen all version <- constant(0),
                   simple_trigger_id <- uuid(),
                   parent_trigger_id <- uuid(),
                   routing_key <- amqp_name(),
                   static_headers <- static_headers(),
                   exchange <- one_of([constant(nil), amqp_name()]),
                   message_expiration_ms <- integer(1..2_147_483_647),
                   message_priority <- integer(0..9),
                   message_persistent <- boolean(),
                   params: params do
      %AMQPTriggerTarget{
        version: version,
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        routing_key: routing_key,
        static_headers: static_headers,
        exchange: exchange,
        message_expiration_ms: message_expiration_ms,
        message_priority: message_priority,
        message_persistent: message_persistent
      }
    end
  end

  defp amqp_name, do: string(@amqp_name_chars, min_length: 1, max_length: 64)

  defp static_headers,
    do: map_of(amqp_name(), string(:alphanumeric, max_length: 64), max_length: 8)
end
