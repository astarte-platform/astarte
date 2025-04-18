#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.RealmTest do
  alias Astarte.Test.Helpers.Database
  alias Astarte.RealmManagement.Engine

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties

  describe "Test Realm" do
    @describetag :realm
    property "Fetches device_registration limit correctly", %{realm: realm} do
      check all(limit <- integer(1..256)) do
        Database.insert_device_registration_limit!(realm, limit)
        assert {:ok, ^limit} = Engine.get_device_registration_limit(realm)
      end
    end

    property "retrieve datasteam_maximum_storage_retention correctly", %{realm: realm} do
      check all(retention <- integer(1..256)) do
        Database.set_datastream_maximum_storage_retention(realm, retention)
        assert {:ok, ^retention} = Engine.get_datastream_maximum_storage_retention(realm)
      end
    end
  end
end
