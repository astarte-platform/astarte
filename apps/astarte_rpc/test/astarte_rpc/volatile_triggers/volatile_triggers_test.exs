#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.RPC.VolatileTriggersTest do
  use Astarte.RPC.Cases.Database, async: true
  use Mimic

  import StreamData, only: [map: 2]

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Interface
  alias Astarte.RPC.Server
  alias Astarte.RPC.VolatileTriggers
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerDeletion
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerInstallation
  alias Phoenix.PubSub

  setup_all do
    fixed_endpoint_interface = fixed_endpoint_interface() |> Enum.at(0)

    fixed_endpoint_interface_id =
      CQLUtils.interface_id(fixed_endpoint_interface.name, fixed_endpoint_interface.major_version)

    %{
      fixed_endpoint_interface: fixed_endpoint_interface,
      fixed_endpoint_interface_id: fixed_endpoint_interface_id
    }
  end

  setup do
    VolatileTriggers.subscribe_all()

    trigger_id = UUID.uuid4(:raw)

    %{trigger_id: trigger_id}
  end

  describe "subscribe_all/0" do
    test ~s(subscribes the current process to "volatile-triggers:*") do
      expect(PubSub, :subscribe, fn Server, "volatile-triggers:*" -> :ok end)
      VolatileTriggers.subscribe_all()
    end
  end

  describe "install/4" do
    test "sends an install trigger message to all the replicas for device triggers", context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:device_trigger, %{device_event_type: :INTERFACE_ADDED}}
        }
      }

      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "sends an install trigger message to all the replicas for all interface data triggers",
         context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger:
            {:data_trigger, %{interface_name: "*", data_trigger_type: :INCOMING_DATA}}
        }
      }

      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "sends an install trigger message to all the replicas for all paths data triggers",
         context do
      %{
        realm_name: realm_name
      } = context

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, %{match_path: "/*", data_trigger_type: :INCOMING_DATA}}
        }
      }

      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "sends an install trigger message to all the replicas for path specific data triggers",
         context do
      %{
        realm_name: realm_name,
        fixed_endpoint_interface: interface
      } = context

      interface_specific_trigger = %{
        data_trigger_type: :INCOMING_DATA,
        interface_name: interface.name,
        interface_major: interface.major_version,
        match_path: "/value"
      }

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, interface_specific_trigger}
        }
      }

      expect_fetch_interface(interface)
      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "loads the interface from the database if the given data does not have it in cache",
         context do
      %{
        realm_name: realm_name,
        fixed_endpoint_interface: interface
      } = context

      interface_specific_trigger = %{
        data_trigger_type: :INCOMING_DATA,
        interface_name: interface.name,
        interface_major: interface.major_version,
        match_path: "/value"
      }

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, interface_specific_trigger}
        }
      }

      expect_fetch_interface(interface)
      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "does not load the interface from the database if the given data already has it in cache",
         context do
      %{
        realm_name: realm_name,
        fixed_endpoint_interface: interface,
        fixed_endpoint_interface_id: interface_id
      } = context

      data = %{
        interface_ids_to_name: %{interface_id => interface.name},
        interfaces: %{interface.name => interface}
      }

      interface_specific_trigger = %{
        data_trigger_type: :INCOMING_DATA,
        interface_name: interface.name,
        interface_major: interface.major_version,
        match_path: "/value"
      }

      tagged_simple_trigger = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, interface_specific_trigger}
        }
      }

      reject_fetch_interface(interface)
      VolatileTriggers.install(realm_name, tagged_simple_trigger, nil, data)

      assert_receive %VolatileTriggerInstallation{}
    end

    test "does nothing if the interfaces can't be found", context do
      %{
        realm_name: realm_name
      } = context

      # an invalid interface is not installed
      invalid_interface_data_trigger =
        %{
          interface_name: ".",
          interface_major: 1,
          match_path: "/value"
        }

      tagged_simple_trigger_with_interface_not_installed = %{
        simple_trigger_container: %{
          simple_trigger: {:data_trigger, invalid_interface_data_trigger}
        }
      }

      Mimic.reject(&PubSub.broadcast/3)

      assert {:error, :interface_not_found} ==
               VolatileTriggers.install(
                 realm_name,
                 tagged_simple_trigger_with_interface_not_installed,
                 nil
               )
    end
  end

  describe "delete/2" do
    test "sends a delete trigger message to all the replicas", context do
      %{
        realm_name: realm_name,
        trigger_id: trigger_id
      } = context

      VolatileTriggers.delete(realm_name, trigger_id)

      assert_receive %VolatileTriggerDeletion{trigger_id: ^trigger_id}
    end
  end

  defp fixed_endpoint_interface do
    InterfaceGenerator.interface(ownership: :device, type: :datastream, aggregation: :individual)
    |> map(fn interface ->
      mapping = Enum.at(interface.mappings, 0)
      mapping = %{mapping | endpoint: "/value", value_type: :integer}

      %{interface | mappings: [mapping]}
    end)
  end

  defp expect_fetch_interface(interface) do
    # TODO: remove this function once we have interface installation in some library
    name = interface.name
    major = interface.major_version
    descriptor = interface_to_descriptor(interface)

    Interface
    |> expect(:fetch_interface_descriptor, fn _, ^name, ^major -> {:ok, descriptor} end)
  end

  defp reject_fetch_interface(_interface) do
    reject(&Interface.fetch_interface_descriptor/3)
  end

  defp interface_to_descriptor(interface) do
    %{name: name, major_version: major_version} = interface
    interface_id = CQLUtils.interface_id(name, major_version)

    %InterfaceDescriptor{
      interface_id: interface_id,
      name: name,
      major_version: major_version
    }
  end
end
