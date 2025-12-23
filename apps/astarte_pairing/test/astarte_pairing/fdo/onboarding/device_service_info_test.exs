defmodule Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo

  describe "decode/1" do
    test "correctly decodes a valid payload (IsMore=false, Empty List)" do
      payload = [false, []]
      assert {:ok, %DeviceServiceInfo{} = msg} = DeviceServiceInfo.decode(payload)
      assert msg.is_more_service_info == false
      assert msg.service_info == %{}
    end

    test "correctly decodes a valid payload with data (IsMore=true)" do
      info_list = [["devmod:os", "linux"], ["devmod:version", "1.0"]]

      info_list =
        Enum.map(info_list, fn [key, value] ->
          value = value |> CBOR.encode() |> COSE.tag_as_byte()
          [key, value]
        end)

      payload = [true, info_list]

      assert {:ok, msg} = DeviceServiceInfo.decode(payload)
      assert msg.is_more_service_info == true

      assert msg.service_info == %{
               {"devmod", "os"} => "linux",
               {"devmod", "version"} => "1.0"
             }
    end

    test "correctly decodes a Device ServiceInfo payload " do
      complex_service_info = [
        ["devmode:active", true]
      ]

      complex_service_info =
        Enum.map(complex_service_info, fn [key, value] ->
          value = value |> CBOR.encode() |> COSE.tag_as_byte()
          [key, value]
        end)

      payload = [true, complex_service_info]

      assert {:ok, msg} = DeviceServiceInfo.decode(payload)
      assert msg.is_more_service_info == true
      assert is_map(msg.service_info)

      expected_map = %{{"devmode", "active"} => true}

      assert msg.service_info == expected_map
    end

    test "returns error if IsMoreServiceInfo is not a boolean" do
      payload = [1, []]

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(payload)
    end

    test "returns error if IsMoreServiceInfo is nil" do
      payload = [nil, []]

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(payload)
    end

    test "returns error if ServiceInfo is a simple string" do
      payload = [true, ["devmod:os"]]

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(payload)
    end

    test "returns error on invalid structure (list too short)" do
      # Manca l'elemento service_info
      payload = [true]

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(payload)
    end

    test "returns error on invalid structure (list too long)" do
      payload = [true, [], "extra_garbage"]

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(payload)
    end
  end

  describe "to_cbor_list/1" do
    test "converts struct to raw list correctly" do
      msg = %DeviceServiceInfo{
        is_more_service_info: true,
        service_info: ["test_key", "test_val"]
      }

      assert [true, ["test_key", "test_val"]] == DeviceServiceInfo.to_cbor_list(msg)
    end
  end
end
