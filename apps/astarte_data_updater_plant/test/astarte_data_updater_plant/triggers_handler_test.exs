defmodule Astarte.DataUpdaterPlant.TriggersHandlerTest do
  use ExUnit.Case

  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Queue
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.TriggersHandler

  @queue_name "test_events_queue"
  @routing_key "test_routing_key"
  @realm "test"
  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @interface "com.Test.Interface"
  @path "/some/path"
  @bson_value %{v: "testvalue"} |> Bson.encode()

  setup_all do
    {:ok, conn} = Connection.open(Config.amqp_producer_options())
    {:ok, chan} = Channel.open(conn)
    {:ok, _queue} = Queue.declare(chan, @queue_name)
    :ok = Queue.bind(chan, @queue_name, Config.events_exchange_name(), routing_key: @routing_key)

    on_exit fn ->
      Channel.close(chan)
      Connection.close(conn)
    end

    [chan: chan]
  end

  setup %{chan: chan} do
    test_pid = self()

    {:ok, consumer_tag} =
      AMQP.Queue.subscribe(chan, @queue_name, fn payload, meta ->
        send(test_pid, {:event, payload, meta})
      end)

    on_exit fn ->
      AMQP.Queue.unsubscribe(chan, consumer_tag)
    end
  end

  test "on_incoming_data AMQPTarget handling" do
    simple_trigger_id = :uuid.get_v4()
    parent_trigger_id = :uuid.get_v4()
    static_header_key = "important_metadata"
    static_header_value = "test_meta"
    static_headers = [{static_header_key, static_header_value}]

    target =
      %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

    TriggersHandler.on_incoming_data(target, @realm, @device_id, @interface, @path, @bson_value)

    assert_receive {:event, payload, meta}

    assert %SimpleEvent{
      device_id: @device_id,
      parent_trigger_id: ^parent_trigger_id,
      simple_trigger_id: ^simple_trigger_id,
      realm: @realm,
      event: {:incoming_data_event, incoming_data_event}
    } = SimpleEvent.decode(payload)

    assert %IncomingDataEvent{
      interface: @interface,
      path: @path,
      bson_value: @bson_value
    } = incoming_data_event

    headers_map = amqp_headers_to_map(meta.headers)

    assert Map.get(headers_map, "x_astarte_realm") == @realm
    assert Map.get(headers_map, "x_astarte_device_id") == @device_id
    assert Map.get(headers_map, "x_astarte_event_type") == "incoming_data_event"
    assert Map.get(headers_map, static_header_key) == static_header_value
  end

  test "on_value_change AMQPTarget handling" do
    simple_trigger_id = :uuid.get_v4()
    parent_trigger_id = :uuid.get_v4()
    static_header_key = "important_metadata_value_change"
    static_header_value = "test_meta_value_change"
    static_headers = [{static_header_key, static_header_value}]
    old_bson_value = %{v: 41} |> Bson.encode()
    new_bson_value = %{v: 42} |> Bson.encode()

    target =
      %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

    TriggersHandler.on_value_change(target, @realm, @device_id, @interface, @path, old_bson_value, new_bson_value)

    assert_receive {:event, payload, meta}

    assert %SimpleEvent{
      device_id: @device_id,
      parent_trigger_id: ^parent_trigger_id,
      simple_trigger_id: ^simple_trigger_id,
      realm: @realm,
      event: {:value_change_event, value_change_event}
    } = SimpleEvent.decode(payload)

    assert %ValueChangeEvent{
      interface: @interface,
      path: @path,
      old_bson_value: ^old_bson_value,
      new_bson_value: ^new_bson_value
    } = value_change_event

    headers_map = amqp_headers_to_map(meta.headers)

    assert Map.get(headers_map, "x_astarte_realm") == @realm
    assert Map.get(headers_map, "x_astarte_device_id") == @device_id
    assert Map.get(headers_map, "x_astarte_event_type") == "value_change_event"
    assert Map.get(headers_map, static_header_key) == static_header_value
  end

  test "on_value_change_applied AMQPTarget handling" do
    simple_trigger_id = :uuid.get_v4()
    parent_trigger_id = :uuid.get_v4()
    static_header_key = "important_metadata_value_change_applied"
    static_header_value = "test_meta_value_change_applied"
    static_headers = [{static_header_key, static_header_value}]
    old_bson_value = %{v: 41} |> Bson.encode()
    new_bson_value = %{v: 42} |> Bson.encode()

    target =
      %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

    TriggersHandler.on_value_change_applied(target, @realm, @device_id, @interface, @path, old_bson_value, new_bson_value)

    assert_receive {:event, payload, meta}

    assert %SimpleEvent{
      device_id: @device_id,
      parent_trigger_id: ^parent_trigger_id,
      simple_trigger_id: ^simple_trigger_id,
      realm: @realm,
      event: {:value_change_applied_event, value_change_applied_event}
    } = SimpleEvent.decode(payload)

    assert %ValueChangeAppliedEvent{
      interface: @interface,
      path: @path,
      old_bson_value: ^old_bson_value,
      new_bson_value: ^new_bson_value
    } = value_change_applied_event

    headers_map = amqp_headers_to_map(meta.headers)

    assert Map.get(headers_map, "x_astarte_realm") == @realm
    assert Map.get(headers_map, "x_astarte_device_id") == @device_id
    assert Map.get(headers_map, "x_astarte_event_type") == "value_change_applied_event"
    assert Map.get(headers_map, static_header_key) == static_header_value
  end


  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
end
