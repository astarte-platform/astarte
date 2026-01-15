#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.DataAccess.Config.XandraNodes do
  use Skogsra.Type

  @impl Skogsra.Type
  @spec cast(String.t()) :: {:ok, [String.t()]} | :error
  def cast(value)

  def cast(""), do: :error

  def cast(value) when is_binary(value) do
    nodes =
      String.split(value, ",", trim: true)
      |> Enum.map(&String.trim/1)

    {:ok, nodes}
  end

  def cast(_) do
    :error
  end
end
