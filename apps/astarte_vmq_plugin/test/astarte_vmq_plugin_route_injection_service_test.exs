defmodule Astarte.VMQ.Plugin.HealthHttp.RouteInjectionServiceTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.VMQ.Plugin.HealthHttp.RouteInjectionService

  setup do
    # start a dummy Cowboy/Ranch listener in which to inject routes
    dispatch = :cowboy_router.compile([{:_, []}])
    server_ref = make_ref()

    on_exit(fn ->
      :cowboy.stop_listener(server_ref)
    end)

    {:ok, _listener_pid} =
      :cowboy.start_clear(
        server_ref,
        [{:port, 0}],
        %{env: %{dispatch: dispatch}}
      )

    listener_port = :ranch.get_port(server_ref)

    %{server_ref: server_ref, listener_port: listener_port}
  end

  describe "Route injection service" do
    test "successfully injects custom routes into live Ranch listener", %{
      server_ref: srv_ref,
      listener_port: port
    } do
      assert {:ok, injector_pid} =
               RouteInjectionService.start_link(
                 http_metrics_port: port,
                 inject_custom_routes: true
               )

      # wait for the GenServer to finish its injection and stop cleanly
      injector_ref = Process.monitor(injector_pid)
      assert_receive {:DOWN, ^injector_ref, :process, ^injector_pid, :normal}, 2000

      # verify the route was merged into the Ranch protocol options
      routes = extract_routes_from_ranch_protocol_options(srv_ref)
      assert "healthz" in routes
    end

    test "ignores route injection when disabled in configuration", %{
      server_ref: srv_ref,
      listener_port: port
    } do
      assert :ignore =
               RouteInjectionService.start_link(
                 http_metrics_port: port,
                 inject_custom_routes: false
               )

      routes = extract_routes_from_ranch_protocol_options(srv_ref)
      assert "healthz" not in routes
    end

    test "reports an error if the listener is not available for injecting routes", %{
      listener_port: port
    } do
      Process.flag(:trap_exit, true)

      # start the injection service declaring a wrong port => listener not found
      inactive_port = port - 1

      {:ok, pid} =
        RouteInjectionService.start_link(
          http_metrics_port: inactive_port,
          inject_custom_routes: true
        )

      assert_receive {:EXIT, ^pid, :routes_injection_failed}, 2000
    end
  end

  defp extract_routes_from_ranch_protocol_options(server_ref) do
    opts = :ranch.get_protocol_options(server_ref)
    dispatch = opts.env.dispatch
    [{:_, [], paths}] = dispatch
    Enum.map(paths, fn {[path_matches], _, _, _} -> path_matches end)
  end
end
