defmodule Astarte.Core.Interface.EnumsTest do
  use ExUnit.Case

  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type

  # Hardcode the values to avoid changing the serialization by accident
  test "Interface.Aggregation consistency" do
    assert Aggregation.to_int(:individual) == 1
    assert Aggregation.from_int(1) == :individual

    assert Aggregation.to_int(:object) == 2
    assert Aggregation.from_int(2) == :object
  end

  test "Interface.Ownership consistency" do
    assert Ownership.to_int(:device) == 1
    assert Ownership.from_int(1) == :device

    assert Ownership.to_int(:server) == 2
    assert Ownership.from_int(2) == :server
  end

  test "Interface.Type consistency" do
    assert Type.to_int(:properties) == 1
    assert Type.from_int(1) == :properties

    assert Type.to_int(:datastream) == 2
    assert Type.from_int(2) == :datastream
  end
end
