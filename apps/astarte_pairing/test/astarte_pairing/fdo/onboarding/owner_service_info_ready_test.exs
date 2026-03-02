defmodule Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfoReadyTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfoReady

  describe "encode/1" do
    test "encodes nil size as CBOR inside a list" do
      msg = %OwnerServiceInfoReady{max_device_service_info_sz: nil}

      encoded_binary = OwnerServiceInfoReady.encode(msg)

      assert {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)
      assert [nil] == decoded_list
    end

    test "encodes custom integer size correctly" do
      custom_size = System.unique_integer([:positive])
      msg = %OwnerServiceInfoReady{max_device_service_info_sz: custom_size}

      encoded_binary = OwnerServiceInfoReady.encode(msg)

      assert {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)
      assert [custom_size] == decoded_list
    end
  end

  describe "to_cbor_list/1" do
    test "returns the raw list required for CBOR encoding" do
      msg = %OwnerServiceInfoReady{max_device_service_info_sz: 100}
      assert [100] == OwnerServiceInfoReady.to_cbor_list(msg)
    end
  end
end
