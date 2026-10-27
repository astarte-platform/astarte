defmodule Astarte.Core.Mapping.EnumsTest do
  use ExUnit.Case

  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType

  # Hardcode the values to avoid changing the serialization by accident
  test "Mapping.ValueType consistency" do
    assert ValueType.to_int(:double) == 1
    assert ValueType.from_int(1) == :double

    assert ValueType.to_int(:doublearray) == 2
    assert ValueType.from_int(2) == :doublearray

    assert ValueType.to_int(:integer) == 3
    assert ValueType.from_int(3) == :integer

    assert ValueType.to_int(:integerarray) == 4
    assert ValueType.from_int(4) == :integerarray

    assert ValueType.to_int(:longinteger) == 5
    assert ValueType.from_int(5) == :longinteger

    assert ValueType.to_int(:longintegerarray) == 6
    assert ValueType.from_int(6) == :longintegerarray

    assert ValueType.to_int(:string) == 7
    assert ValueType.from_int(7) == :string

    assert ValueType.to_int(:stringarray) == 8
    assert ValueType.from_int(8) == :stringarray

    assert ValueType.to_int(:boolean) == 9
    assert ValueType.from_int(9) == :boolean

    assert ValueType.to_int(:booleanarray) == 10
    assert ValueType.from_int(10) == :booleanarray

    assert ValueType.to_int(:binaryblob) == 11
    assert ValueType.from_int(11) == :binaryblob

    assert ValueType.to_int(:binaryblobarray) == 12
    assert ValueType.from_int(12) == :binaryblobarray

    assert ValueType.to_int(:datetime) == 13
    assert ValueType.from_int(13) == :datetime

    assert ValueType.to_int(:datetimearray) == 14
    assert ValueType.from_int(14) == :datetimearray
  end

  test "Mapping.Reliability consistency" do
    assert Reliability.to_int(:unreliable) == 1
    assert Reliability.from_int(1) == :unreliable

    assert Reliability.to_int(:guaranteed) == 2
    assert Reliability.from_int(2) == :guaranteed

    assert Reliability.to_int(:unique) == 3
    assert Reliability.from_int(3) == :unique
  end

  test "Mapping.Retention consistency" do
    assert Retention.to_int(:discard) == 1
    assert Retention.from_int(1) == :discard

    assert Retention.to_int(:volatile) == 2
    assert Retention.from_int(2) == :volatile

    assert Retention.to_int(:stored) == 3
    assert Retention.from_int(3) == :stored
  end
end
