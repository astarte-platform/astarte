defmodule Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumerTest do
  use Astarte.Cases.FakeRabbitPool, async: true
  use Astarte.Cases.Policy
  use Mimic

  alias AMQP.Channel
  alias Astarte.TriggerEngine.AMQPConsumer.AMQPMessageConsumer.Impl

  import Astarte.Helpers.AMQPMessageConsumer

  describe "connect/2" do
    @tag :unit
    test "connects to the channel with a valid realm name and policy", args do
      %{realm_name: realm_name, policy: policy} = args

      assert {:ok, channel, monitor} = Impl.connect(realm_name, policy)
      assert %Channel{} = channel
      assert is_reference(monitor)
    end

    @tag :unit
    test "monitors the channel process", args do
      %{realm_name: realm_name, policy: policy} = args

      {:ok, channel, monitor} = Impl.connect(realm_name, policy)
      %{pid: pid} = channel
      kill_channel(channel)

      assert_receive {:DOWN, ^monitor, :process, ^pid, _reason}
    end
  end
end
