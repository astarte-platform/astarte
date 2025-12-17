defmodule Astarte.DataUpdaterPlant.RPC.Replica.CoreTest do
  use Astarte.Cases.Server, async: true
  use Astarte.Cases.Trigger

  use ExUnitProperties
  use Mimic

  alias Astarte.DataUpdaterPlant.RPC.Replica.Core
  alias Astarte.Events.Triggers

  setup :verify_on_exit!

  describe "handle_result/1" do
    test "returns ok if all servers respond :ok" do
      multi_call_response = {[{self(), :ok}], []}

      assert :ok == Core.handle_result(multi_call_response)
    end

    test "returns ok if there are bad nodes" do
      multi_call_response = {[], [self()]}

      assert :ok == Core.handle_result(multi_call_response)
    end

    test "returns an error if there is an error" do
      multi_call_response = {[{self(), :ok}, {self(), {:error, :reason}}, {self(), :ok}], []}

      assert {:error, :reason} == Core.handle_result(multi_call_response)
    end
  end

  describe "multi_call/3" do
    test "calls all the given processes", context do
      %{ping_pong: server} = context

      replicas = [server, server, server]
      message = :message

      Core.multi_call(replicas, message)

      assert_receive {:call, ^message}
      assert_receive {:call, ^message}
      assert_receive {:call, ^message}
    end

    test "returns the list of replies in the first tuple element", context do
      %{ping_pong: server} = context

      replicas = [server, server]
      key = System.unique_integer()

      assert {ok, []} = Core.multi_call(replicas, key)
      assert [{server, key}, {server, key}] == ok
    end

    test "returns the list of bad servers in the second tuple element", context do
      %{ignore: ignore} = context

      # self is not a genserver
      bad_servers = [ignore, self()]

      assert {[], error} = Core.multi_call(bad_servers, :message, 0)
      assert self() in error
      assert ignore in error
    end
  end

  describe "install_trigger/5" do
    test "calls the install trigger function from astarte_events", context do
      %{
        data: data,
        policy: policy,
        realm_name: realm_name,
        tagged_simple_trigger: tagged_simple_trigger,
        trigger_target: trigger_target
      } = context

      Triggers
      |> expect(:install_trigger, fn
        ^realm_name, ^tagged_simple_trigger, ^trigger_target, ^policy, ^data -> :ok
      end)

      Core.install_trigger(realm_name, tagged_simple_trigger, trigger_target, policy, data)
    end
  end

  describe "delete_trigger/4" do
    test "calls the delete trigger function from astarte_events", context do
      %{
        data: data,
        realm_name: realm_name,
        tagged_simple_trigger: tagged_simple_trigger,
        trigger_id: trigger_id
      } = context

      Triggers
      |> expect(:delete_trigger, fn
        ^realm_name, ^trigger_id, ^tagged_simple_trigger, ^data -> :ok
      end)

      Core.delete_trigger(realm_name, trigger_id, tagged_simple_trigger, data)
    end
  end
end
