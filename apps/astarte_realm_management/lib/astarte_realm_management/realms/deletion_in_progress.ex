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

defmodule Astarte.RealmManagement.Realms.DeletionInProgress do
  @moduledoc false

  use TypedEctoSchema

  alias __MODULE__, as: Data

  @primary_key false
  schema "deletion_in_progress" do
    field :device_id, Astarte.DataAccess.UUID, primary_key: true
    field :vmq_ack, :boolean
    field :dup_start_ack, :boolean
    field :dup_end_ack, :boolean
  end

  def all_ack?(%Data{} = deletion) do
    %Data{vmq_ack: vmq, dup_start_ack: dup_start, dup_end_ack: dup_end} = deletion

    vmq and dup_start and dup_end
  end
end
