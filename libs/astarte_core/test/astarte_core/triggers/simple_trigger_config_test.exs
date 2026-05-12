defmodule Astarte.Core.SimpleTriggerConfigTest do
  use ExUnit.Case

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersUtils
  alias Ecto.Changeset

  @interface_name "com.Test.Interface"
  @interface_major 1
  @match_path "/some/path"
  @int_known_value 42
  @string_known_value "somestring"
  @valid_data_trigger_map %{
    "type" => "data_trigger",
    "interface_name" => @interface_name,
    "interface_major" => @interface_major,
    "on" => "incoming_data",
    "value_match_operator" => ">",
    "match_path" => @match_path,
    "known_value" => @int_known_value
  }
  @valid_data_trigger_any_map %{
    "type" => "data_trigger",
    "interface_name" => @interface_name,
    "interface_major" => @interface_major,
    "on" => "value_change",
    "match_path" => @match_path,
    "value_match_operator" => "*"
  }

  @device_id :crypto.strong_rand_bytes(16)
  @encoded_device_id Device.encode_device_id(@device_id)
  @valid_device_trigger_map %{
    "type" => "device_trigger",
    "on" => "device_connected"
  }

  test "changeset with invalid trigger_type returns an error changeset" do
    invalid_type = %{@valid_data_trigger_map | "type" => "invalid"}

    assert {:error, %Changeset{}} =
             SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_type)
             |> Ecto.Changeset.apply_action(:insert)
  end

  describe "data triggers" do
    test "changeset with invalid on returns an error changeset" do
      invalid_on = %{@valid_data_trigger_map | "on" => "invalid"}

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_on)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with invalid value_match_operator returns an error changeset" do
      invalid_operator = %{@valid_data_trigger_map | "value_match_operator" => "?"}

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_operator)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with value_match_operator != * and no known value returns an error changeset" do
      no_known_value = Map.delete(@valid_data_trigger_map, "known_value")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, no_known_value)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with interface_name == * and match_path != /* returns an error changeset" do
      any_interface = Map.put(@valid_data_trigger_map, "interface_name", "*")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, any_interface)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with interface_name == * and on != incoming_data returns an error changeset" do
      params = %{
        "type" => "data_trigger",
        "interface_name" => "*",
        "on" => "value_change",
        "match_path" => "/*",
        "value_match_operator" => "*"
      }

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, params)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with match_path == /* and value_match_operator != * returns an error changeset" do
      any_path = Map.put(@valid_data_trigger_map, "match_path", "/*")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, any_path)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset generates a SimpleTriggerConfig from a valid data trigger map to_tagged_simple_trigger converts it to a TaggedSimpleTrigger" do
      interface_id = CQLUtils.interface_id(@interface_name, @interface_major)
      data_trigger_type = :INCOMING_DATA
      match_operator = :GREATER_THAN
      known_value = Cyanide.encode!(%{v: @int_known_value})

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, @valid_data_trigger_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "data_trigger",
               interface_name: @interface_name,
               interface_major: @interface_major,
               on: "incoming_data",
               value_match_operator: ">",
               match_path: @match_path,
               known_value: @int_known_value
             } = config

      assert %TaggedSimpleTrigger{
               object_id: ^interface_id,
               object_type: 2,
               simple_trigger_container: simple_trigger_container
             } = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: @interface_name,
               interface_major: @interface_major,
               value_match_operator: ^match_operator,
               match_path: @match_path,
               known_value: ^known_value
             } = data_trigger
    end

    test "changeset generates a SimpleTriggerConfig from a valid data trigger map with any operator" do
      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, @valid_data_trigger_any_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "data_trigger",
               interface_name: @interface_name,
               interface_major: @interface_major,
               on: "value_change",
               value_match_operator: "*",
               match_path: @match_path,
               known_value: nil
             } = config
    end
  end

  describe "device triggers" do
    test "changeset with invalid on returns an error changeset" do
      invalid_on = %{@valid_device_trigger_map | "on" => "invalid"}

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_on)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with invalid device id returns an error changeset" do
      invalid_id = Map.put(@valid_device_trigger_map, "device_id", "invalidid")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_id)
               |> Ecto.Changeset.apply_action(:insert)

      too_long_id =
        Map.put(
          @valid_device_trigger_map,
          "device_id",
          Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
        )

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, too_long_id)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with both device id and group name returns an error changeset" do
      device_and_group =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("group_name", "mygroup")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, device_and_group)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map" do
      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, @valid_device_trigger_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "device_connected"
             } = config
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map with * device" do
      any_device_map = Map.put(@valid_device_trigger_map, "device_id", "*")

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, any_device_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "device_connected",
               device_id: "*"
             } = config
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map with specific device" do
      device_map = Map.put(@valid_device_trigger_map, "device_id", @encoded_device_id)

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, device_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "device_connected",
               device_id: @encoded_device_id
             } = config
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map with group_name" do
      group_name = "mygroup"

      group_map = Map.put(@valid_device_trigger_map, "group_name", group_name)

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, group_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "device_connected",
               group_name: ^group_name
             } = config
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map with specific device and introspection condition" do
      device_map =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("on", "incoming_introspection")

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, device_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "incoming_introspection",
               device_id: @encoded_device_id
             } = config
    end

    test "changeset with invalid interface_name without interface_major on interface_added returns an error changeset" do
      invalid_interface_name =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("interface_name", @interface_name)
        |> Map.put("on", "interface_added")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_interface_name)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with invalid interface_name without interface_major on interface_removed returns an error changeset" do
      invalid_interface_name =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("interface_name", @interface_name)
        |> Map.put("on", "interface_removed")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_interface_name)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with invalid any interface name on interface_minor_updated returns an error changeset" do
      invalid_interface_name =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("interface_name", "*")
        |> Map.put("on", "interface_minor_updated")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_interface_name)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset with invalid interface name on incoming_introspection returns an error changeset" do
      invalid_interface_name =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("interface_name", "*")
        |> Map.put("on", "incoming_introspection")

      assert {:error, %Changeset{}} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, invalid_interface_name)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "changeset generates a SimpleTriggerConfig from a valid device trigger map interface and major on introspection_added" do
      device_map =
        @valid_device_trigger_map
        |> Map.put("device_id", @encoded_device_id)
        |> Map.put("on", "interface_added")
        |> Map.put("interface_name", @interface_name)
        |> Map.put("interface_major", 1)

      assert {:ok, %SimpleTriggerConfig{} = config} =
               SimpleTriggerConfig.changeset(%SimpleTriggerConfig{}, device_map)
               |> Ecto.Changeset.apply_action(:insert)

      assert %SimpleTriggerConfig{
               type: "device_trigger",
               on: "interface_added",
               device_id: @encoded_device_id,
               interface_name: @interface_name,
               interface_major: 1
             } = config
    end
  end

  describe "conversion to and from TaggedSimpleTrigger" do
    test "data SimpleTriggerConfig roundtrips" do
      interface_id = CQLUtils.interface_id(@interface_name, @interface_major)
      data_trigger_type = :INCOMING_DATA
      match_operator = :GREATER_THAN
      known_value = Cyanide.encode!(%{v: @int_known_value})

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "incoming_data",
        value_match_operator: ">",
        match_path: @match_path,
        known_value: @int_known_value
      }

      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^interface_id,
               object_type: 2,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: @interface_name,
               interface_major: @interface_major,
               value_match_operator: ^match_operator,
               match_path: @match_path,
               known_value: ^known_value
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "data SimpleTriggerConfig roundtrips with any interface" do
      any_interface_object_id = SimpleTriggersUtils.any_interface_object_id()
      any_interface_object_type_int = SimpleTriggersUtils.object_type_to_int!(:any_interface)
      data_trigger_type = :VALUE_CHANGE
      match_operator = :CONTAINS
      known_value = Cyanide.encode!(%{v: @string_known_value})

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        interface_name: "*",
        on: "value_change",
        value_match_operator: "contains",
        match_path: @match_path,
        known_value: @string_known_value
      }

      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^any_interface_object_id,
               object_type: ^any_interface_object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: "*",
               interface_major: nil,
               value_match_operator: ^match_operator,
               match_path: @match_path,
               known_value: ^known_value
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device-specific data SimpleTriggerConfig roundtrips" do
      interface_id = CQLUtils.interface_id(@interface_name, @interface_major)
      data_trigger_type = :INCOMING_DATA
      match_operator = :GREATER_THAN
      known_value = Cyanide.encode!(%{v: @int_known_value})

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        device_id: @encoded_device_id,
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "incoming_data",
        value_match_operator: ">",
        match_path: @match_path,
        known_value: @int_known_value
      }

      object_id = SimpleTriggersUtils.get_device_and_interface_object_id(@device_id, interface_id)
      object_type_int = SimpleTriggersUtils.object_type_to_int!(:device_and_interface)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^object_id,
               object_type: ^object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: @interface_name,
               interface_major: @interface_major,
               value_match_operator: ^match_operator,
               match_path: @match_path,
               known_value: ^known_value
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device-specific data SimpleTriggerConfig roundtrips with any interface" do
      data_trigger_type = :INCOMING_DATA
      match_operator = :ANY

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        device_id: @encoded_device_id,
        interface_name: "*",
        on: "incoming_data",
        value_match_operator: "*",
        match_path: "/*"
      }

      object_id = SimpleTriggersUtils.get_device_and_any_interface_object_id(@device_id)
      object_type_int = SimpleTriggersUtils.object_type_to_int!(:device_and_any_interface)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^object_id,
               object_type: ^object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: "*",
               interface_major: nil,
               value_match_operator: ^match_operator,
               match_path: "/*"
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "group-specific data SimpleTriggerConfig roundtrips" do
      interface_id = CQLUtils.interface_id(@interface_name, @interface_major)
      data_trigger_type = :INCOMING_DATA
      match_operator = :GREATER_THAN
      known_value = Cyanide.encode!(%{v: @int_known_value})
      group_name = "mygroup"

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        group_name: group_name,
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "incoming_data",
        value_match_operator: ">",
        match_path: @match_path,
        known_value: @int_known_value
      }

      object_id = SimpleTriggersUtils.get_group_and_interface_object_id(group_name, interface_id)
      object_type_int = SimpleTriggersUtils.object_type_to_int!(:group_and_interface)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^object_id,
               object_type: ^object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: @interface_name,
               interface_major: @interface_major,
               value_match_operator: ^match_operator,
               match_path: @match_path,
               known_value: ^known_value
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "group-specific data SimpleTriggerConfig roundtrips with any interface" do
      data_trigger_type = :INCOMING_DATA
      match_operator = :ANY
      group_name = "mygroup"

      config = %SimpleTriggerConfig{
        type: "data_trigger",
        group_name: group_name,
        interface_name: "*",
        on: "incoming_data",
        value_match_operator: "*",
        match_path: "/*"
      }

      object_id = SimpleTriggersUtils.get_group_and_any_interface_object_id(group_name)
      object_type_int = SimpleTriggersUtils.object_type_to_int!(:group_and_any_interface)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^object_id,
               object_type: ^object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:data_trigger, data_trigger}} =
               simple_trigger_container

      assert %DataTrigger{
               data_trigger_type: ^data_trigger_type,
               interface_name: "*",
               interface_major: nil,
               value_match_operator: ^match_operator,
               match_path: "/*"
             } = data_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device SimpleTriggerConfig roundtrips" do
      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected",
        device_id: Device.encode_device_id(@device_id)
      }

      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: @device_id,
               object_type: 1,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:device_trigger, device_trigger}} =
               simple_trigger_container

      assert %DeviceTrigger{
               device_event_type: :DEVICE_DISCONNECTED
             } = device_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device SimpleTriggerConfig roundtrips with empty device_id" do
      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected"
      }

      any_device_object_id = SimpleTriggersUtils.any_device_object_id()
      any_device_object_type_int = SimpleTriggersUtils.object_type_to_int!(:any_device)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^any_device_object_id,
               object_type: ^any_device_object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:device_trigger, device_trigger}} =
               simple_trigger_container

      assert %DeviceTrigger{
               device_event_type: :DEVICE_DISCONNECTED
             } = device_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device SimpleTriggerConfig roundtrips with any device id" do
      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected",
        device_id: "*"
      }

      any_device_object_id = SimpleTriggersUtils.any_device_object_id()
      any_device_object_type_int = SimpleTriggersUtils.object_type_to_int!(:any_device)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^any_device_object_id,
               object_type: ^any_device_object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:device_trigger, device_trigger}} =
               simple_trigger_container

      assert %DeviceTrigger{
               device_event_type: :DEVICE_DISCONNECTED
             } = device_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end

    test "device SimpleTriggerConfig roundtrips with group_name" do
      group_name = "foobar"

      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected",
        group_name: group_name
      }

      group_object_id = SimpleTriggersUtils.get_group_object_id(group_name)
      group_object_type_int = SimpleTriggersUtils.object_type_to_int!(:group)
      tagged_simple_trigger = SimpleTriggerConfig.to_tagged_simple_trigger(config)

      assert %TaggedSimpleTrigger{
               object_id: ^group_object_id,
               object_type: ^group_object_type_int,
               simple_trigger_container: simple_trigger_container
             } = tagged_simple_trigger

      assert %SimpleTriggerContainer{simple_trigger: {:device_trigger, device_trigger}} =
               simple_trigger_container

      assert %DeviceTrigger{
               device_event_type: :DEVICE_DISCONNECTED
             } = device_trigger

      assert config == SimpleTriggerConfig.from_tagged_simple_trigger(tagged_simple_trigger)
    end
  end

  describe "JSON encode" do
    test "data SimpleTriggerConfig is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "data_trigger",
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "value_change_applied",
        value_match_operator: "<",
        match_path: @match_path,
        known_value: @int_known_value
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "data_trigger",
                 "interface_name" => @interface_name,
                 "interface_major" => @interface_major,
                 "on" => "value_change_applied",
                 "value_match_operator" => "<",
                 "match_path" => @match_path,
                 "known_value" => @int_known_value
               })
    end

    test "data SimpleTriggerConfig with device_id is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "data_trigger",
        device_id: @encoded_device_id,
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "value_change_applied",
        value_match_operator: "<",
        match_path: @match_path,
        known_value: @int_known_value
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "data_trigger",
                 "device_id" => @encoded_device_id,
                 "interface_name" => @interface_name,
                 "interface_major" => @interface_major,
                 "on" => "value_change_applied",
                 "value_match_operator" => "<",
                 "match_path" => @match_path,
                 "known_value" => @int_known_value
               })
    end

    test "data SimpleTriggerConfig with group_name is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "data_trigger",
        group_name: "mygroup",
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "value_change_applied",
        value_match_operator: "<",
        match_path: @match_path,
        known_value: @int_known_value
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "data_trigger",
                 "group_name" => "mygroup",
                 "interface_name" => @interface_name,
                 "interface_major" => @interface_major,
                 "on" => "value_change_applied",
                 "value_match_operator" => "<",
                 "match_path" => @match_path,
                 "known_value" => @int_known_value
               })
    end

    test "data SimpleTriggerConfig with any operator is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "data_trigger",
        interface_name: @interface_name,
        interface_major: @interface_major,
        on: "value_change_applied",
        value_match_operator: "*",
        match_path: @match_path,
        known_value: @int_known_value
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "data_trigger",
                 "interface_name" => @interface_name,
                 "interface_major" => @interface_major,
                 "on" => "value_change_applied",
                 "match_path" => @match_path,
                 "value_match_operator" => "*"
               })
    end

    test "data SimpleTriggerConfig with any interface is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "data_trigger",
        interface_name: "*",
        interface_major: @interface_major,
        on: "value_change_applied",
        value_match_operator: "<",
        match_path: @match_path,
        known_value: @int_known_value
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "data_trigger",
                 "interface_name" => "*",
                 "on" => "value_change_applied",
                 "value_match_operator" => "<",
                 "match_path" => @match_path,
                 "known_value" => @int_known_value
               })
    end

    test "device SimpleTriggerConfig is correctly encoded" do
      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected"
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "device_trigger",
                 "on" => "device_disconnected"
               })
    end

    test "device SimpleTriggerConfig with device_id is correctly encoded" do
      device_id = Device.encode_device_id(@device_id)

      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected",
        device_id: device_id
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "device_trigger",
                 "on" => "device_disconnected",
                 "device_id" => device_id
               })
    end

    test "device SimpleTriggerConfig with group_name is correctly encoded" do
      group_name = "mygroup"

      config = %SimpleTriggerConfig{
        type: "device_trigger",
        on: "device_disconnected",
        group_name: group_name
      }

      assert Jason.encode(config) ==
               Jason.encode(%{
                 "type" => "device_trigger",
                 "on" => "device_disconnected",
                 "group_name" => group_name
               })
    end
  end
end
