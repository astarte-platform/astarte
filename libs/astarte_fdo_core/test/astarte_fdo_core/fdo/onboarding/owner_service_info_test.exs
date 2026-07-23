defmodule Astarte.FDO.Core.OwnerOnboarding.OwnerServiceInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.OwnerServiceInfo

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

      _expected_service_info =
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
      assert [true, false, _chunk_data] = decoded_list
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

  describe "empty/0" do
    test "returns an empty owner service info" do
      result = OwnerServiceInfo.empty()
      assert {:ok, owner_service_info} = OwnerServiceInfo.cbor_decode(result)

      assert owner_service_info == %OwnerServiceInfo{
               is_done: false,
               is_more_service_info: false,
               service_info: %{}
             }
    end
  end

  describe "done/0" do
    test "returns an empty owner service info with isdone=true" do
      result = OwnerServiceInfo.done()
      assert {:ok, owner_service_info} = OwnerServiceInfo.cbor_decode(result)

      assert owner_service_info == %OwnerServiceInfo{
               is_done: true,
               is_more_service_info: false,
               service_info: %{}
             }
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

  describe "encode_with_service_info_chunk/2" do
    test "encodes flags and pre-encoded service info chunk" do
      msg = %OwnerServiceInfo{
        is_more_service_info: true,
        is_done: false,
        service_info: %{}
      }

      encoded_chunk = [["astarte:realm", CBOR.encode("test_realm") |> COSE.tag_as_byte()]]
      encoded = OwnerServiceInfo.encode_with_service_info_chunk(msg, encoded_chunk)

      assert {:ok, %OwnerServiceInfo{} = decoded} = OwnerServiceInfo.cbor_decode(encoded)
      assert "test_realm" == decoded.service_info[{"astarte", "realm"}]
    end
  end

  describe "build/4" do
    test "builds owner service info with astarte keys and modules metadata" do
      built =
        OwnerServiceInfo.build(
          "test_realm",
          "credentials_secret",
          "encoded_device_id",
          "https://api.example.com"
        )

      assert %OwnerServiceInfo{
               is_more_service_info: false,
               is_done: true,
               service_info: service_info
             } =
               built

      assert service_info["astarte:active"] == true
      assert service_info["astarte:realm"] == "test_realm"
      assert service_info["astarte:secret"] == "credentials_secret"
      assert service_info["astarte:baseurl"] == "https://api.example.com"
      assert service_info["astarte:deviceid"] == "encoded_device_id"
      assert service_info["astarte:nummodules"] == 5

      assert [5, 5 | modules] = service_info["astarte:modules"]

      assert Enum.sort(modules) ==
               Enum.sort([
                 "astarte:active",
                 "astarte:realm",
                 "astarte:secret",
                 "astarte:baseurl",
                 "astarte:deviceid"
               ])
    end
  end
end
