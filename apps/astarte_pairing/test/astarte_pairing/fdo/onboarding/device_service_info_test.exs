defmodule Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo

  describe "decode/1" do
    test "correctly decodes a valid payload (IsMore=false, Empty List)" do
      cbor_payload = CBOR.encode([false, []])
      assert {:ok, %DeviceServiceInfo{} = msg} = DeviceServiceInfo.decode(cbor_payload)
      assert msg.is_more_service_info == false
      assert msg.service_info == %{}
    end

    test "correctly decodes a valid payload with data (IsMore=true)" do
      info_list = [["devmod:os", CBOR.encode("linux")], ["devmod:version", CBOR.encode("1.0")]]
      cbor_payload = CBOR.encode([true, info_list])

      assert {:ok, msg} = DeviceServiceInfo.decode(cbor_payload)
      assert msg.is_more_service_info == true

      assert msg.service_info ==
               %{"devmod:os" => "linux", "devmod:version" => "1.0"}
    end

    test "correctly decodes a Astarte ServiceInfo payload " do
      complex_service_info = [
        ["astarte:active", CBOR.encode(true)],
        ["astarte:realm", CBOR.encode("test_realm")],
        ["astarte:secret", CBOR.encode("super_secret_credential")],
        ["astarte:baseurl", CBOR.encode("http://api.astarte.localhost")],
        ["astarte:deviceid", CBOR.encode("2TBn-jNESuuHamE2Zo1anA")],
        ["astarte:nummodules", CBOR.encode(1)],
        ["astarte:modules", CBOR.encode([1, 0, "astarte_interface_1", "astarte_interface_2"])]
      ]

      cbor_payload = CBOR.encode([true, complex_service_info])

      assert {:ok, msg} = DeviceServiceInfo.decode(cbor_payload)
      assert msg.is_more_service_info == true
      assert is_map(msg.service_info)

      expected_map = %{
        "astarte:active" => true,
        "astarte:realm" => "test_realm",
        "astarte:baseurl" => "http://api.astarte.localhost",
        "astarte:deviceid" => "2TBn-jNESuuHamE2Zo1anA",
        "astarte:modules" => [1, 0, "astarte_interface_1", "astarte_interface_2"],
        "astarte:nummodules" => 1,
        "astarte:secret" => "super_secret_credential"
      }

      assert msg.service_info == expected_map
    end

    test "returns error if IsMoreServiceInfo is not a boolean" do
      cbor_payload = CBOR.encode([1, []])

      assert {:error, :invalid_is_more_type} = DeviceServiceInfo.decode(cbor_payload)
    end

    test "returns error if IsMoreServiceInfo is nil" do
      cbor_payload = CBOR.encode([nil, []])

      assert {:error, :invalid_is_more_type} = DeviceServiceInfo.decode(cbor_payload)
    end

    test "returns error if ServiceInfo is a simple string" do
      cbor_payload = CBOR.encode([true, ["devmod:os"]])

      assert {:error, :message_body_error} = DeviceServiceInfo.decode(cbor_payload)
    end

    test "returns error on invalid structure (list too short)" do
      # Manca l'elemento service_info
      cbor_payload = CBOR.encode([true])

      assert {:error, :invalid_structure} = DeviceServiceInfo.decode(cbor_payload)
    end

    test "returns error on invalid structure (list too long)" do
      cbor_payload = CBOR.encode([true, [], "extra_garbage"])

      assert {:error, :invalid_structure} = DeviceServiceInfo.decode(cbor_payload)
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
