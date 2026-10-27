defmodule Astarte.VMQ.Plugin.HealthHttp.RouteInjectionService do
  @moduledoc """
  Service for injection of custom Cowboy HTTP handlers at VerneMQ startup.
  In production builds it leverages the Erlang modules loaded in the underlying VerneMQ host.
  """

  require Logger

  use GenServer, restart: :transient

  alias Astarte.VMQ.Plugin.HealthHttp.Handler

  @default_http_metrics_port 8888
  @max_retries 10
  @retry_interval_ms 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    # the http_metrics_port needs to match the actual listening port of the cowboy server
    http_metrics_port = Keyword.get(opts, :http_metrics_port, @default_http_metrics_port)

    # it can be declared explicitly whether to inject routes, or it can be inferred from
    # env configuration; by default runs only in a VerneMQ container
    injection_enabled? =
      Keyword.get(
        opts,
        :inject_custom_routes,
        Application.get_env(
          :astarte_vmq_plugin,
          :inject_custom_routes
        )
      )

    if injection_enabled? do
      state = %{listener_port: http_metrics_port, retries_left: @max_retries}
      {:ok, state, {:continue, :inject_custom_routes}}
    else
      Logger.debug("Injection of custom http routes skipped for this environment")
      :ignore
    end
  end

  @impl true
  def handle_continue(:inject_custom_routes, state) do
    attempt_routes_injection(state)
  end

  @impl true
  def handle_info(:inject_custom_routes, %{retries_left: 0} = state) do
    Logger.error("Injection of custom http routes failed")
    {:stop, :routes_injection_failed, state}
  end

  @impl true
  def handle_info(:inject_custom_routes, state) do
    attempt_routes_injection(state)
  end

  defp attempt_routes_injection(
         %{listener_port: listener_port, retries_left: retries_left} = state
       ) do
    listener_ref = get_listener_ref(listener_port)

    case listener_ref do
      # cowboy server may not be ready yet
      nil ->
        state = %{state | retries_left: retries_left - 1}
        Process.send_after(self(), :inject_custom_routes, @retry_interval_ms)
        {:noreply, state}

      ref ->
        do_inject_custom_routes(ref)
        Logger.info("Injection of custom http routes succeeded")
        {:stop, :normal, state}
    end
  end

  # check if cowboy listener is running on defined port
  defp get_listener_ref(listener_port) do
    Enum.find_value(:ranch.info(), fn {ref, details} ->
      if Map.get(details, :port) == listener_port, do: ref, else: nil
    end)
  end

  defp do_inject_custom_routes(listener_ref) do
    custom_routes = Handler.routes()

    [{:_, [], custom_paths}] = :cowboy_router.compile([{:_, custom_routes}])

    # live Cowboy configuration
    opts = :ranch.get_protocol_options(listener_ref)
    env = Map.get(opts, :env, %{})
    existing_dispatch = Map.get(env, :dispatch, [])

    # merge new compiled paths into the existing paths
    new_dispatch =
      Enum.map(existing_dispatch, fn {host, constraints, paths} ->
        {host, constraints, paths ++ custom_paths}
      end)

    # apply the updated routing table to the live server
    new_env = Map.put(env, :dispatch, new_dispatch)
    new_opts = Map.put(opts, :env, new_env)
    :ranch.set_protocol_options(listener_ref, new_opts)
  end
end
