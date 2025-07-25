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

defmodule Astarte.Core.Generators.StorageType do
  @moduledoc """
  This module provides generators for StorageType.
  """
  alias Astarte.Core.StorageType

  use ExUnitProperties

  @doc """
  Generates a valid Astarte StorageType
  """
  @spec storage_type() :: StreamData.t(StorageType.t())
  def storage_type do
    member_of([
      :multi_interface_individual_properties_dbtable,
      :multi_interface_individual_datastream_dbtable,
      :one_individual_properties_dbtable,
      :one_individual_datastream_dbtable,
      :one_object_datastream_dbtable
    ])
  end

  @doc """
  Convert this struct stream to changes
  """
  @spec to_changes(StreamData.t(StorageType.t())) :: StreamData.t(integer())
  def to_changes(gen) do
    gen |> map(&StorageType.to_int/1)
  end
end
