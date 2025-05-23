#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.AMQPDataConsumer.ConnectionManager do
  @behaviour :gen_statem

  defmodule Data do
    defstruct [
      :connection_opts,
      :connection,
      :monitor_ref,
      pending_callers: []
    ]
  end

  require Logger

  @connection_backoff 10000

  def start_link(init_args) do
    :gen_statem.start_link({:local, __MODULE__}, __MODULE__, init_args, [])
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def get_connection do
    # Defaults to infinity timeout, we exploit that to make
    # channel initialization wait for the connection to be up
    :gen_statem.call(__MODULE__, :get_connection)
  end

  @impl true
  def callback_mode do
    :state_functions
  end

  @impl true
  def init(init_args) do
    connection_opts = Keyword.fetch!(init_args, :amqp_opts)
    data = %Data{connection_opts: connection_opts}
    actions = [{:next_event, :internal, :connect}]

    {:ok, :disconnected, data, actions}
  end

  def disconnected(:internal, :connect, data) do
    %Data{
      connection_opts: opts
    } = data

    case AMQP.Connection.open(opts) do
      {:ok, conn} ->
        ref = Process.monitor(conn.pid)
        new_data = %{data | monitor_ref: ref, connection: conn}
        actions = [{:next_event, :internal, :reply_all}]
        {:next_state, :connected, new_data, actions}

      {:error, reason} ->
        Logger.warning(
          "RabbitMQ Connection error: #{inspect(reason)}. " <>
            "Retrying connection in #{@connection_backoff} ms.",
          tag: "data_consumer_conn_err"
        )

        actions = [{:state_timeout, @connection_backoff, :reconnect}]
        {:keep_state_and_data, actions}
    end
  end

  def disconnected(:state_timeout, :reconnect, _data) do
    actions = [{:next_event, :internal, :connect}]
    {:keep_state_and_data, actions}
  end

  def disconnected({:call, from}, :get_connection, data) do
    # We save the caller and we'll reply when we are connected
    %Data{
      pending_callers: pending_callers
    } = data

    new_data = %{data | pending_callers: [from | pending_callers]}
    {:keep_state, new_data}
  end

  def connected(:internal, :reply_all, data) do
    # When we enter the connected state, we reply with the connection to all the callers
    %Data{
      connection: conn,
      pending_callers: pending_callers
    } = data

    actions = for caller <- pending_callers, do: {:reply, caller, conn}
    new_data = %{data | pending_callers: []}
    {:keep_state, new_data, actions}
  end

  def connected({:call, from}, :get_connection, data) do
    %Data{
      connection: conn
    } = data

    actions = [{:reply, from, conn}]
    {:keep_state_and_data, actions}
  end

  def connected(
        :info,
        {:DOWN, monitor_ref, :process, _pid, reason},
        %Data{
          monitor_ref: monitor_ref
        } = data
      ) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Trying to reconnect...",
      tag: "data_consumer_conn_lost"
    )

    actions = {:next_event, :internal, :connect}
    new_data = %{data | connection: nil, monitor_ref: nil}

    {:next_state, :disconnected, new_data, actions}
  end
end
