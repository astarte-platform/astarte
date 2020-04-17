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

defmodule Astarte.AppEngine.API.Config.NonNegativeInteger do
  use Skogsra.Type

  @impl Skogsra.Type
  @spec cast(String.t()) :: {:ok, non_neg_integer()} | :error
  def cast(value)

  def cast(""), do: :error

  def cast(value) when is_binary(value) do
    with {limit, _} <- Integer.parse(value) do
      if limit >= 0 do
        {:ok, limit}
      else
        {:ok, 0}
      end
    else
      :error ->
        :error
    end
  end

  def cast(_) do
    :error
  end
end
