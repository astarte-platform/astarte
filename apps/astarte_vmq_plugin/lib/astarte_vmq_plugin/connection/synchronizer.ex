#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.VMQ.Plugin.Connection.Synchronizer do
  @moduledoc """
    This module handles connection and disconnection events. As it may happen that
    VerneMQ hooks are called in the wrong order if events occur in a delta of ~10 ms,
    the module forces the correct order of publication (i.e. disconnection before reconnection).
    See https://github.com/vernemq/vernemq/issues/1741.
  """
  alias Astarte.VMQ.Plugin
  @behaviour :gen_statem

  # Hooks might be called in the wrong order if the time difference is ~10 ms.
  # Let's play it safe with 50 ms.
  @timeout_ms 50

  defmodule Data do
    @moduledoc "Internal state for the connection/disconnection synchronization state machine."

    defstruct [
      :client_id,
      :connection_headers,
      :connection_timestamp,
      :connection_from,
      :disconnection_headers,
      :disconnection_timestamp,
      :disconnection_from
    ]
  end

  # API

  @impl true
  def callback_mode do
    [:state_functions]
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient
    }
  end

  def start_link(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    name = via_tuple(client_id)

    :gen_statem.start_link(name, __MODULE__, opts, [])
  end

  def handle_connection(pid, timestamp, additional_headers \\ []) do
    :gen_statem.call(pid, {:connection, timestamp, additional_headers})
  end

  def handle_disconnection(pid, timestamp, additional_headers \\ []) do
    :gen_statem.call(pid, {:disconnection, timestamp, additional_headers})
  end

  # Callbacks

  @impl true
  def init(init_args) do
    client_id = Keyword.fetch!(init_args, :client_id)
    data = %Data{client_id: client_id}
    {:ok, :accept, data}
  end

  def accept({:call, from}, {:connection, timestamp, additional_headers}, data) do
    new_data = %{
      data
      | connection_timestamp: timestamp,
        connection_headers: additional_headers,
        connection_from: from
    }

    {:next_state, :has_connection, new_data, [timeout_action()]}
  end

  def accept({:call, from}, {:disconnection, timestamp, additional_headers}, data) do
    new_data = %{
      data
      | disconnection_timestamp: timestamp,
        disconnection_headers: additional_headers,
        disconnection_from: from
    }

    {:next_state, :has_disconnection, new_data, [timeout_action()]}
  end

  def has_connection(
        {:call, disconnection_from},
        {:disconnection, disconnection_timestamp, disconnection_headers},
        %Data{
          client_id: client_id,
          connection_timestamp: connection_timestamp,
          connection_headers: connection_headers,
          connection_from: connection_from
        }
      ) do
    Plugin.publish_event(
      client_id,
      "disconnection",
      disconnection_timestamp,
      disconnection_headers
    )

    Plugin.publish_event(client_id, "connection", connection_timestamp, connection_headers)

    :gen_statem.reply(disconnection_from, :ok)
    :gen_statem.reply(connection_from, :ok)

    {:stop, :normal}
  end

  def has_connection(:timeout, _content, data) do
    Plugin.publish_event(
      data.client_id,
      "connection",
      data.connection_timestamp,
      data.connection_headers
    )

    :gen_statem.reply(data.connection_from, :ok)

    {:stop, :normal}
  end

  def has_disconnection(
        {:call, connection_from},
        {:connection, connection_timestamp, connection_headers},
        %Data{
          client_id: client_id,
          disconnection_timestamp: disconnection_timestamp,
          disconnection_headers: disconnection_headers,
          disconnection_from: disconnection_from
        }
      ) do
    Plugin.publish_event(
      client_id,
      "disconnection",
      disconnection_timestamp,
      disconnection_headers
    )

    Plugin.publish_event(client_id, "connection", connection_timestamp, connection_headers)

    :gen_statem.reply(disconnection_from, :ok)
    :gen_statem.reply(connection_from, :ok)

    {:stop, :normal}
  end

  def has_disconnection(:timeout, _content, data) do
    Plugin.publish_event(
      data.client_id,
      "disconnection",
      data.disconnection_timestamp,
      data.disconnection_headers
    )

    :gen_statem.reply(data.disconnection_from, :ok)
    {:stop, :normal}
  end

  def via_tuple(client_id) do
    {:via, Registry, {AstarteVMQPluginConnectionSynchronizer.Registry, client_id}}
  end

  defp timeout_action do
    {
      :timeout,
      @timeout_ms,
      nil
    }
  end
end
