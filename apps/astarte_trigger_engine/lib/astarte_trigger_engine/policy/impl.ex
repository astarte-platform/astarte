#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.Policy.Impl do
  # TODO use the ExRabbitPool.RabbitMQ adapter when it will have a `nack` function
  alias AMQP.Basic
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.TriggerEngine.Config
  alias Astarte.TriggerEngine.Policy.State

  alias AMQP.Channel

  require Logger

  @type amqp_header_type() ::
          :longstr
          | :signedint
          | :decimal
          | :timestamp
          | :table
          | :byte
          | :double
          | :float
          | :long
          | :short
          | :bool
          | :binary
          | :void
          | :array

  @type amqp_header() :: {String.t(), amqp_header_type(), term()}
  @type meta() :: %{
          :message_id => State.message_id(),
          :delivery_tag => integer(),
          optional(:headers) => [amqp_header()]
        }

  @consumer Config.events_consumer!()

  @spec handle_event(State.t(), Channel.t(), term(), meta()) :: State.t()
  def handle_event(state, channel, payload, meta) do
    {headers, _other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    message_id = meta.message_id

    handle_start_map =
      Map.put_new_lazy(state.handle_start_map, message_id, fn ->
        start = System.monotonic_time()

        :telemetry.execute(
          [:astarte, :trigger_engine, :handle_event],
          %{start: start},
          %{
            realm: state.realm,
            message_id: message_id
          }
        )

        start
      end)

    verify_event_consumed = @consumer.consume(payload, headers_map)
    retry_map = Map.update(state.retry_map, message_id, 1, fn value -> value + 1 end)

    new_state = %{state | retry_map: retry_map, handle_start_map: handle_start_map}

    _ =
      Logger.debug(
        "Handling event #{meta.message_id}, this is the #{Map.get(retry_map, meta.message_id)}-th time"
      )

    case verify_event_consumed do
      # All was ok
      :ok ->
        Basic.ack(channel, meta.delivery_tag)
        {start, handle_start_map} = Map.pop!(handle_start_map, message_id)
        finish = System.monotonic_time()
        retry_map = Map.delete(retry_map, message_id)

        :telemetry.execute(
          [:astarte, :trigger_engine, :handle_event],
          %{duration: finish - start},
          %{
            realm: state.realm,
            message_id: message_id
          }
        )

        %{state | retry_map: retry_map, handle_start_map: handle_start_map}

      {:http_error, status_code} ->
        maybe_requeue_message(channel, meta, status_code, new_state)

      {:error, :connection_error} ->
        maybe_requeue_message(channel, meta, 503, new_state)

      {:error, :trigger_not_found} ->
        discard_message(channel, meta, new_state)
    end
  end

  defp maybe_requeue_message(chan, meta, status_code, state) do
    if should_requeue_message?(meta.message_id, status_code, state) do
      requeue_message(chan, meta, state)
    else
      discard_message(chan, meta, state)
    end
  end

  defp requeue_message(chan, meta, state) do
    Basic.nack(chan, meta.delivery_tag, requeue: true)

    state
  end

  defp discard_message(chan, meta, state) do
    Basic.nack(chan, meta.delivery_tag, requeue: false)

    retry_map = Map.delete(state.retry_map, meta.message_id)
    %{state | retry_map: retry_map}
  end

  defp should_requeue_message?(
         event_id,
         error_number,
         state
       ) do
    %State{
      policy: %Policy{error_handlers: handlers, retry_times: retry_times},
      retry_map: retry_map
    } = state

    handler = Enum.find(handlers, fn handler -> Handler.includes?(handler, error_number) end)

    retry? =
      handler != nil and not Handler.discards?(handler) and retry_times != nil and
        Map.get(retry_map, event_id) < retry_times

    _ = Logger.debug("Event #{event_id} was processed; scheduled for retry? #{retry?}")
    retry?
  end

  defp amqp_headers_to_map(headers) do
    Map.new(headers, fn {key, _type, value} -> {key, value} end)
  end
end
