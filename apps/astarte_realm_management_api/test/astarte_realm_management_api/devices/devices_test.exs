#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.DevicesTest do
  use Astarte.RealmManagement.API.DataCase

  alias Astarte.RealmManagement.API.Devices
  alias Astarte.RealmManagement.Mock.DB

  @realm "testrealm"

  test "delete device succeeds when the device exists" do
    device_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    DB.create_device(@realm, device_id)

    assert :ok = Devices.delete_device(@realm, device_id)
  end

  test "delete device fails when the device does not exists" do
    missing_device_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    assert {:error, :device_not_found} = Devices.delete_device(@realm, missing_device_id)
  end
end
