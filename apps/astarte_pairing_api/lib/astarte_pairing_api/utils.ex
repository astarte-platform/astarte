# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.Pairing.API.Utils do
  @moduledoc """
  Utility functions for Pairing API.
  """

  @doc """
  Takes a changeset and an error map and adds the errors
  to the changeset.
  """
  def error_map_into_changeset(%Ecto.Changeset{} = changeset, error_map) do
    Enum.reduce(error_map, %{changeset | valid?: false}, fn
      {k, v}, acc when is_binary(v) and v != "" ->
        Ecto.Changeset.add_error(acc, k, v)

      _, acc ->
        acc
    end)
  end
end
