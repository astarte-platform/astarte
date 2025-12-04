defmodule Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo

  describe "encode/1" do
    test "correctly encodes a standard message (IsMore=false, IsDone=false)" do
      service_info = %{"devmod:active" => true, "astarte:realm" => "test"}

      expected_service_info =
        [
          ["devmod:active", CBOR.encode(true) |> COSE.tag_as_byte()],
          ["astarte:realm", CBOR.encode("test") |> COSE.tag_as_byte()]
        ]
        |> Enum.sort()

      msg = %OwnerServiceInfo{
        is_more_service_info: false,
        is_done: false,
        service_info: service_info
      }

      encoded_binary = OwnerServiceInfo.encode(msg)

      assert {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)
      assert [false, false, received_service_info] = decoded_list
      assert Enum.sort(received_service_info) == expected_service_info
    end

    test "correctly encodes a fragmentation message (IsMore=true)" do
      chunk_data = %{"big_config" => "part_1"}

      expected_service_info =
        [
          ["big_config", CBOR.encode("part_1") |> COSE.tag_as_byte()]
        ]
        |> Enum.sort()

      msg = %OwnerServiceInfo{
        is_more_service_info: true,
        is_done: false,
        service_info: chunk_data
      }

      encoded_binary = OwnerServiceInfo.encode(msg)

      assert {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)
      assert [true, false, chunk_data] = decoded_list
    end

    test "correctly encodes the Done message (IsDone=true)" do
      msg = %OwnerServiceInfo{
        is_more_service_info: false,
        is_done: true,
        service_info: []
      }

      encoded_binary = OwnerServiceInfo.encode(msg)

      assert {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)
      assert [false, true, []] = decoded_list
    end

    test "correctly encodes nested data in ServiceInfo" do
      nested_modules = [1, 0, "module_name"]
      complex_info = %{"astarte:modules" => nested_modules}

      expected_service_info =
        [
          ["astarte:modules", CBOR.encode(nested_modules) |> COSE.tag_as_byte()]
        ]
        |> Enum.sort()

      msg = %OwnerServiceInfo{
        is_more_service_info: false,
        is_done: false,
        service_info: complex_info
      }

      encoded_binary = OwnerServiceInfo.encode(msg)

      {:ok, decoded_list, ""} = CBOR.decode(encoded_binary)

      [_is_more, _is_done, decoded_service_info] = decoded_list
      assert decoded_service_info == expected_service_info
    end
  end

  describe "to_cbor_list/1" do
    test "returns the raw list required for CBOR encoding" do
      msg = %OwnerServiceInfo{
        is_more_service_info: false,
        is_done: false,
        service_info: %{"k" => "v"}
      }

      assert [false, false, [["k", %CBOR.Tag{tag: :bytes, value: "av"}]]] ==
               OwnerServiceInfo.to_cbor_list(msg)
    end
  end
end
