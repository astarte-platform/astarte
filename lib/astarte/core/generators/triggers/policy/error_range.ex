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

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorRange do
  @moduledoc """
  This module provides generators for Astarte Trigger Policy RangeError.
  """
  alias Astarte.Core.Generators.Triggers.Policy.ErrorRange
  alias Astarte.Core.Triggers.Policy.ErrorRange

  import Astarte.Generators.Utilities.ParamsGen

  use ExUnitProperties

  @doc """
  Generates a valid Astarte Triggers Policy ErrorRange from scratch
  """
  @spec error_range() :: StreamData.t(ErrorRange.t())
  @spec error_range(params :: keyword()) :: StreamData.t(ErrorRange.t())
  def error_range(params \\ []) do
    params gen all error_codes <- error_codes(), params: params do
      %ErrorRange{
        error_codes: error_codes
      }
    end
  end

  @doc """
  Convert this struct/stream to changes
  """
  @spec to_changes(ErrorRange.t()) :: StreamData.t(map())
  def to_changes(data) when not is_struct(data, StreamData),
    do: data |> constant() |> to_changes()

  @spec to_changes(StreamData.t(ErrorRange.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %ErrorRange{error_codes: error_codes} <- gen do
      %{
        "error_codes" => error_codes
      }
    end
  end

  defp error_codes do
    integer(400..599)
    |> list_of(min_length: 1)
    |> map(&Enum.uniq/1)
  end
end
