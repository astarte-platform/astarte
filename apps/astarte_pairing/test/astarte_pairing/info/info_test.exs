#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.InfoTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  alias Astarte.Pairing.Info.DeviceInfo
  alias Astarte.Pairing.Info

  import Astarte.Helpers.Device

  @credentials_secret "7wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
  @wrong_credentials_secret "8wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
  @version Mix.Project.config()[:version]
  @status "confirmed"
  @broker_url "mqtts://broker.beta.astarte.cloud:8883/"

  setup_all [:set_credentials_secret]

  def set_credentials_secret(ctx) do
    update_device!(ctx.realm_name, ctx.device.id, inhibit_credentials_request: false)
    update_credentials_secret!(ctx.realm_name, ctx.device.id, @credentials_secret)

    :ok
  end

  describe "device_info" do
    test "returns valid info with authorized call", ctx do
      %{realm_name: realm_name, device: device} = ctx

      assert {:ok, %DeviceInfo{status: @status, version: @version, protocols: protocols}} =
               Info.get_device_info(realm_name, device.encoded_id, @credentials_secret)

      assert %{astarte_mqtt_v1: %{broker_url: @broker_url}} = protocols
    end

    test "returns forbidden with forbidden call", ctx do
      %{realm_name: realm_name, device: device} = ctx

      assert {:error, :forbidden} =
               Info.get_device_info(realm_name, device.encoded_id, @wrong_credentials_secret)
    end
  end
end
