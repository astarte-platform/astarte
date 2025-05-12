#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind srl
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

defmodule Astarte.Housekeeping.API.Realms.NonNegativeIntegerOrUnsetType do
  use Ecto.Type
  def type, do: :any

  def cast(:unset), do: {:ok, :unset}

  def cast(n) when is_integer(n) do
    if n >= 0, do: {:ok, n}, else: :error
  end

  def cast(_), do: :error

  # load and dump are not meaningful for our use-case
  # coveralls-ignore-start
  def load(:unset), do: {:ok, :unset}
  def load(n) when is_integer(n), do: {:ok, n}
  def load(_), do: :error
  def dump(:unset), do: {:ok, :unset}
  def dump(n) when is_integer(n), do: {:ok, n}
  def dump(_), do: :error
end
