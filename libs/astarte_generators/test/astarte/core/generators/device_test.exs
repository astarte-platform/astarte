#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Core.Generators.DeviceTest do
  @moduledoc """
  Tests for Astarte Device generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Device
  import Astarte.Core.Generators.Interface

  alias Astarte.Core.Device

  @moduletag :device

  @device_id_size 16

  @doc false
  describe "device generator ids" do
    @tag :success
    property "success valid device id size" do
      check all device_id <- device_id() do
        assert byte_size(device_id) == @device_id_size,
               "Device id is not #{@device_id_size} bytes"
      end
    end

    @tag :success
    property "success encode device id" do
      check all device_id <- device_id() do
        encoded_device_id_1 = Base.url_encode64(device_id, padding: false)
        encoded_device_id_2 = Device.encode_device_id(device_id)
        assert encoded_device_id_1 == encoded_device_id_2
      end
    end

    @tag :success
    property "success decode device id" do
      check all encoded_device_id <- device_encoded_id() do
        {:ok, device_id_1} = Base.url_decode64(encoded_device_id, padding: false)
        {:ok, device_id_2} = Device.decode_device_id(encoded_device_id)
        assert device_id_1 == device_id_2
      end
    end
  end

  @doc false
  describe "device generator struct" do
    @tag :success
    property "success base device creation" do
      check all device <- device() do
        refute is_nil(device)
      end
    end

    @tag :success
    @tag issue: 42
    property "device nillable fields" do
      check all device <-
                  device(
                    last_seen_ip: nil,
                    last_credentials_request_ip: nil,
                    inhibit_credentials_request: nil,
                    last_disconnection: nil,
                    last_connection: nil,
                    first_credentials_request: nil,
                    first_registration: nil,
                    aliases: nil,
                    attributes: nil
                  ) do
        refute is_nil(device)
      end
    end
  end

  describe "coverage" do
    property "success device with nil now triggers nil timestamp fallbacks" do
      check all device <- device(now: nil) do
        refute is_nil(device)
      end
    end

    property "success device with single interface struct" do
      check all device <- device(interfaces: interface()) do
        refute is_nil(device)
      end
    end

    property "success device with duplicate interfaces triggers map update" do
      duplicated = gen all i <- interface(), do: [i, i]

      check all duplicate_interfaces <- duplicated,
                device <- device(interfaces: duplicate_interfaces) do
        refute is_nil(device)
      end
    end
  end
end
