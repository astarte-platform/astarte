defmodule Astarte.AppEngine.API.V2InterfaceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Astarte.Test.Cases.Interface

  alias Ecto.Changeset
  alias StreamData
  alias Astarte.Core.Mapping
  alias Astarte.Core.Interface
  alias Astarte.AppEngine.API.Stats
  alias Astarte.AppEngine.API.Stats.DevicesStats
  alias Astarte.Test.Setups.Database, as: DatabaseSetup
  alias Astarte.Test.Setups.Interface, as: InterfaceSetup
  alias Astarte.Test.Generators.String, as: StringGenerator
  alias Astarte.Test.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Test.Generators.Mapping, as: MappingGenerator
  alias Astarte.Test.Generators.Device, as: DeviceGenerator
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper

  @moduletag :v2
  @moduletag :interface
  @moduletag interface_count: 10

  describe "interface generator" do
    @tag timeout: :infinity
    property "validate interface" do
      check all interface <- InterfaceGenerator.interface() do
        %Changeset{valid?: valid, errors: errors} = Interface.changeset(interface)

        assert valid, "Invalid interface: " <> (errors |> Enum.join(", "))
      end
    end
  end

  describe "interfaces db" do
    test "validate inserted interfaces names", %{
      cluster: cluster,
      keyspace: keyspace,
      interfaces: interfaces
    } do
      list = DatabaseHelper.select!(:interface, cluster, keyspace, interfaces)
      f = fn l -> Enum.map(l, fn i -> i.name end) end
      interfaces_names_a = f.(interfaces)
      interfaces_names_b = f.(list)

      assert [] === interfaces_names_a -- interfaces_names_b
      assert [] === interfaces_names_b -- interfaces_names_a
    end
  end
end
