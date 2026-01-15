defmodule Astarte.Events.Triggers.CoreTest do
  use ExUnit.Case, async: true

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.Events.Triggers.Core

  @any_device_object_id Utils.any_device_object_id()
  @any_device_object_type Utils.object_type_to_int!(:any_device)
  @device_object_type Utils.object_type_to_int!(:device)
  @group_object_type Utils.object_type_to_int!(:group)
  @any_interface_object_id Utils.any_interface_object_id()
  @any_interface_object_type Utils.object_type_to_int!(:any_interface)
  @interface_object_type Utils.object_type_to_int!(:interface)
  @device_and_any_interface_object_type Utils.object_type_to_int!(:device_and_any_interface)
  @device_and_interface_object_type Utils.object_type_to_int!(:device_and_interface)
  @group_and_any_interface_object_type Utils.object_type_to_int!(:group_and_any_interface)
  @group_and_interface_object_type Utils.object_type_to_int!(:group_and_interface)

  describe "object_from_subject/1" do
    test "returns the expected value for :any_device" do
      assert Core.object_from_subject(:any_device) ==
               {@any_device_object_type, @any_device_object_id}
    end

    test "returns the expected value for :device_id" do
      device_id = Device.random_device_id()
      assert Core.object_from_subject({:device_id, device_id}) == {@device_object_type, device_id}
    end

    test "returns the expected value for :group" do
      group_name = "group"
      group_id = Utils.get_group_object_id(group_name)
      assert Core.object_from_subject({:group, group_name}) == {@group_object_type, group_id}
    end

    test "returns the expected value for :any_interface" do
      assert Core.object_from_subject(:any_interface) ==
               {@any_interface_object_type, @any_interface_object_id}
    end

    test "returns the expected value for :interface" do
      interface_id = UUID.uuid4(:raw)

      assert Core.object_from_subject({:interface, interface_id}) ==
               {@interface_object_type, interface_id}
    end

    test "returns the expected value for :group_and_any_interface" do
      group_name = "group"
      group_id = Utils.get_group_and_any_interface_object_id(group_name)

      assert Core.object_from_subject({:group_and_any_interface, group_name}) ==
               {@group_and_any_interface_object_type, group_id}
    end

    test "returns the expected value for :group_and_interface" do
      group_name = "group"
      interface_id = UUID.uuid4(:raw)
      object_id = Utils.get_group_and_interface_object_id(group_name, interface_id)

      assert Core.object_from_subject({:group_and_interface, group_name, interface_id}) ==
               {@group_and_interface_object_type, object_id}
    end

    test "returns the expected value for :device_and_any_interface" do
      device_id = Device.random_device_id()
      object_id = Utils.get_device_and_any_interface_object_id(device_id)

      assert Core.object_from_subject({:device_and_any_interface, device_id}) ==
               {@device_and_any_interface_object_type, object_id}
    end

    test "returns the expected value for :device_and_interface" do
      device_id = Device.random_device_id()
      interface_id = UUID.uuid4(:raw)
      object_id = Utils.get_device_and_interface_object_id(device_id, interface_id)

      assert Core.object_from_subject({:device_and_interface, device_id, interface_id}) ==
               {@device_and_interface_object_type, object_id}
    end
  end
end
