defmodule Astarte.DataUpdaterPlant.RPC.Replica.ReplicaTest do
  use Astarte.Cases.Trigger, async: true
  use Mimic

  alias Astarte.DataUpdaterPlant.RPC.Replica

  setup :verify_on_exit!

  test "registers a process from the current node in registry" do
    nodes = replicas() |> Enum.map(&:erlang.node/1)
    assert node() in nodes
  end

  describe "send_all_replicas/1" do
    test "calls the process on the current node", context do
      %{
        install_trigger_message: message
      } = context

      Replica
      |> expect(:handle_call, fn {:install_trigger, ^message}, _, state ->
        {:reply, :ok, state}
      end)

      allow_current_node()

      Replica.send_all_replicas({:install_trigger, message})
    end

    test "calls all registered processes", context do
      %{
        install_trigger_message: message
      } = context

      replica = own_replica()
      num_replicas = 3
      replicas = 1..num_replicas |> Enum.map(fn _ -> replica end)
      set_replicas(replicas)

      Replica
      |> expect(:handle_call, num_replicas, fn {:install_trigger, ^message}, _, state ->
        {:reply, :ok, state}
      end)

      allow_all_nodes()
      Replica.send_all_replicas({:install_trigger, message})
    end
  end

  describe "init/1" do
    test "registers the current process in the horde registry" do
      assert {:ok, _} = Replica.init([])
      assert self() in replicas()
    end

    test "returns an error if the current process is already registered" do
      assert {:ok, _} = Replica.init([])
      assert {:error, :already_registered} = Replica.init([])
    end
  end

  test "install_trigger calls core install trigger function", context do
    %{
      data: data,
      install_trigger_message: message,
      policy: policy,
      realm_name: realm_name,
      tagged_simple_trigger: tagged_simple_trigger,
      trigger_target: trigger_target
    } = context

    Replica.Core
    |> expect(:install_trigger, fn
      ^realm_name, ^tagged_simple_trigger, ^trigger_target, ^policy, ^data ->
        :ok
    end)

    allow_all_nodes()

    Replica.send_all_replicas({:install_trigger, message})
  end

  test "delete_trigger calls core delete trigger function", context do
    %{
      data: data,
      delete_trigger_message: message,
      realm_name: realm_name,
      tagged_simple_trigger: tagged_simple_trigger,
      trigger_id: trigger_id
    } = context

    Replica.Core
    |> expect(:delete_trigger, fn
      ^realm_name, ^trigger_id, ^tagged_simple_trigger, ^data -> :ok
    end)

    allow_all_nodes()

    Replica.send_all_replicas({:delete_trigger, message})
  end

  defp allow_current_node do
    allow(own_replica())
  end

  defp allow_all_nodes do
    for replica <- replicas() do
      allow(replica)
    end

    :ok
  end

  defp allow(pid) do
    Mimic.allow(Horde.Registry, self(), pid)
    Mimic.allow(Replica.Core, self(), pid)
    Mimic.allow(Replica, self(), pid)
  end

  defp own_replica do
    replicas()
    |> Enum.find(&(:erlang.node(&1) == node()))
  end

  defp replicas do
    Horde.Registry.select(
      Registry.DataUpdaterRPC,
      [{{{:replica, :"$1"}, :_, :_}, [], [:"$1"]}]
    )
  end

  defp set_replicas(replicas) do
    Horde.Registry
    |> stub(:select, fn Registry.DataUpdaterRPC, [{{{:replica, :"$1"}, :_, :_}, [], [:"$1"]}] ->
      replicas
    end)
  end
end
