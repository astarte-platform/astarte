defmodule Astarte.Core.DeviceTest do
  use ExUnit.Case

  alias Astarte.Core.Device

  @invalid_characters_device_id "notbase64§"
  @short_device_id "uTSXEtcgQ3"
  @regular_device_id "74Zp9OoNRc-Vsi5RcsIf4A"
  @long_device_id "uTSXEtcgQ3qczX3ixpZeFrWgx0kxk0bfrUzkqTIhCck"

  test "invalid device ids decoding fails" do
    assert {:error, :invalid_device_id} = Device.decode_device_id(@invalid_characters_device_id)
    assert {:error, :invalid_device_id} = Device.decode_device_id(@short_device_id)
  end

  test "long device ids decoding fails with no options" do
    assert {:error, :extended_id_not_allowed} = Device.decode_device_id(@long_device_id)
  end

  test "regular device id decoding succeeds" do
    assert {:ok, _device_id} = Device.decode_device_id(@regular_device_id)
  end

  test "long device id decoding succeeds with allow_extended_id" do
    assert {:ok, _device_id} = Device.decode_device_id(@long_device_id, allow_extended_id: true)
  end

  test "extended device id decoding succeeds with long id" do
    assert {:ok, _device_id, _extended_device_id} =
             Device.decode_extended_device_id(@long_device_id)
  end

  test "extended device id decoding gives an empty extended id on regular id" do
    assert {:ok, _device_id, ""} = Device.decode_extended_device_id(@regular_device_id)
  end

  test "encoding fails with device id not 128 bit long" do
    assert {:ok, device_id, extended_id} = Device.decode_extended_device_id(@long_device_id)
    long_id = device_id <> extended_id

    assert_raise FunctionClauseError, fn ->
      Device.encode_device_id(long_id)
    end
  end

  test "encoding/decoding roundtrip" do
    assert {:ok, device_id} = Device.decode_device_id(@regular_device_id)
    assert Device.encode_device_id(device_id) == @regular_device_id
  end
end
