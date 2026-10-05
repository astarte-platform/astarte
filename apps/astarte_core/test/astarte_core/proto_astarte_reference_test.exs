defmodule Astarte.Core.AstarteReferenceTest do
  use ExUnit.Case

  describe "payload serialized with ExProtobuf" do
    test "still works for AstarteReference" do
      alias Astarte.Core.AstarteReference

      serialized_reference =
        <<8, 1, 18, 36, 48, 56, 100, 97, 55, 98, 56, 101, 45, 98, 49, 98, 100, 45, 52, 50, 54, 97,
          45, 57, 102, 101, 56, 45, 54, 102, 99, 50, 57, 99, 98, 48, 100, 101, 97, 97>>

      reference = %AstarteReference{
        object_type: 1,
        object_uuid: "08da7b8e-b1bd-426a-9fe8-6fc29cb0deaa"
      }

      assert AstarteReference.encode(reference) == serialized_reference
      assert AstarteReference.decode(serialized_reference) == reference
    end
  end
end
