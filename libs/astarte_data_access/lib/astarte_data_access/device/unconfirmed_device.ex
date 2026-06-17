#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Device.UnconfirmedDevice do
  @moduledoc """
  This module defines the Ecto schema for the `deletion_in_progress` table.
  """
  use TypedEctoSchema

  alias Astarte.DataAccess.DateTime, as: DateTimeMs
  alias Astarte.DataAccess.UUID

  @primary_key {:device_id, UUID, autogenerate: false}
  typed_schema "unconfirmed_devices" do
    field :created_at, DateTimeMs
  end
end
