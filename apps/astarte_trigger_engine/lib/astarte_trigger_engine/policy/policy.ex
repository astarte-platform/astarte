defmodule Astarte.TriggerEngine.Policy do
  use GenServer
  require Logger

  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto
  alias Astarte.TriggerEngine.Config
  alias Astarte.TriggerEngine.Policy.Queries
  alias AMQP.Basic

  @consumer Config.events_consumer!()

  # API
  def start_link(args \\ []) do
    with {:ok, realm_name} <- Keyword.fetch(args, :realm_name),
         {:ok, policy_name} <- Keyword.fetch(args, :policy_name),
         {:ok, pid} <-
           GenServer.start_link(__MODULE__, args, name: via_tuple(realm_name, policy_name)) do
      {:ok, pid}
    else
      :error ->
        # Missing realm or policy in args
        {:error, :no_realm_or_policy_name}

      {:error, {:already_started, pid}} ->
        # Already started, we don't care
        {:ok, pid}

      other ->
        # Relay everything else
        other
    end
  end

  def handle_event(pid, payload, meta, amqp_channel) do
    Logger.debug(
      "policy process #{inspect(pid)} got event, payload: #{inspect(payload)},  meta: #{
        inspect(meta)
      }"
    )

    GenServer.cast(pid, {:handle_event, payload, meta, amqp_channel})
  end

  def get_event_retry_map(pid) do
    Logger.debug("Required event retry map for policy process #{inspect(pid)}")
    GenServer.call(pid, {:get_event_retry_map})
  end

  # Server callbacks

  # default (discard all) policy
  def init(realm_name: _realm_name, policy_name: "@default") do
    {:ok, %{policy: "@default"}}
  end

  def init(realm_name: realm_name, policy_name: policy_name) do
    state = %{realm_name: realm_name, policy_name: policy_name}
    {:ok, state, {:continue, :fetch_from_database}}
  end

  def handle_continue(:fetch_from_database, state) do
    with %{realm_name: realm_name, policy_name: policy_name} <- state,
         {:ok, policy} <- retrieve_policy_data(realm_name, policy_name) do
      {:noreply, %{policy: policy, retry_map: %{}}}
    else
      _ -> {:stop, :initialization_error, %{}}
    end
  end

  # default policy, always discard all
  def handle_cast(
        {:handle_event, payload, meta, amqp_channel},
        %{policy: "@default"} = state
      ) do
    {headers, other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    Logger.debug(
      "got event, payload: #{inspect(payload)}, headers: #{inspect(headers_map)}, meta: #{
        inspect(other_meta)
      }"
    )

    @consumer.consume(payload, headers_map)
    Basic.ack(amqp_channel, meta.delivery_tag)
    {:noreply, state}
  end

  def handle_cast(
        {:handle_event, payload, meta, amqp_channel},
        %{policy: policy, retry_map: retry_map} = state
      ) do
    {headers, other_meta} = Map.pop(meta, :headers, [])
    headers_map = amqp_headers_to_map(headers)

    Logger.debug(
      "got event, payload: #{inspect(payload)}, headers: #{inspect(headers_map)}, meta: #{
        inspect(other_meta)
      }"
    )

    event_consumed? = @consumer.consume(payload, headers_map)
    retry_map = Map.update(retry_map, meta.message_id, 1, fn value -> value + 1 end)

    case event_consumed? do
      # All was ok
      :ok ->
        Basic.ack(amqp_channel, meta.delivery_tag)
        retry_map = Map.delete(retry_map, meta.message_id)
        {:noreply, %{policy: policy, retry_map: retry_map}}

      {:http_error, status_code} ->
        with :ok <- retry_sending?(meta.message_id, status_code, policy, retry_map) do
          Basic.nack(amqp_channel, meta.delivery_tag, requeue: true)
          {:noreply, %{policy: policy, retry_map: retry_map}}
        else
          :no ->
            Basic.nack(amqp_channel, meta.delivery_tag, requeue: false)
            retry_map = Map.delete(retry_map, meta.message_id)
            {:noreply, %{policy: policy, retry_map: retry_map}}
        end

      {:error, :connection_error} ->
        # How do we handle this?
        Logger.warn("Connection error while processing event.")

      {:error, error} ->
        Logger.warn("Error while processing event: #{inspect(error)}")
        error
    end
  end

  def handle_call({:get_event_retry_map}, %{retry_map: retry_map}) do
    {:ok, retry_map}
  end

  defp retry_sending?(event_id, error_number, policy, retry_map) do
    %Policy{error_handlers: handlers} = policy
    handler = Enum.find(handlers, fn handler -> Handler.includes?(handler, error_number) end)

    cond do
      handler == nil -> :no
      Handler.discards?(handler) -> :no
      policy.retry_times == nil -> :no
      Map.get(retry_map, event_id) < policy.retry_times -> :ok
      true -> :no
    end
  end

  defp retrieve_policy_data(realm_name, policy_name) do
    with {:ok, policy_data} <- Queries.retrieve_policy_data(realm_name, policy_name),
         policy_proto <- PolicyProto.decode(policy_data),
         {:ok, policy} <- Policy.from_policy_proto(policy_proto) do
      {:ok, policy}
    else
      error ->
        Logger.warn("Error while retrieving policy: #{inspect(error)}")
        {:error, :policy_retrieving_error}
    end
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp via_tuple(realm_name, policy_name) do
    {:via, Registry, {Registry.PolicyRegistry, {realm_name, policy_name}}}
  end
end
