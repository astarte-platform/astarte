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
#

defmodule Astarte.RealmManagement.Realms.GroupedDevice do
  use TypedEctoSchema

  alias Astarte.RealmManagement.UUID

  @primary_key false
  typed_schema "grouped_devices" do
    field :group_name, :string, primary_key: true
    field :insertion_uuid, UUID, primary_key: true
    field :device_id, UUID, primary_key: true
  end
end
