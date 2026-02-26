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

defmodule Astarte.Core.Generators.Mapping.Payload do
  @moduledoc """
  This module provides Payload generator.
  """
  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.DateTime, as: DateTimeGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

  alias Astarte.Utilities.Map, as: MapUtilities

  @spec payload() :: StreamData.t(map())
  @spec payload(params :: keyword()) :: StreamData.t(map())
  def payload(params \\ []) do
    params gen all type <- ValueTypeGenerator.value_type(),
                   v <- ValueTypeGenerator.value_from_type(type),
                   t <- timestamp(),
                   m <- metadata(),
                   params: params do
      MapUtilities.clean(%{v: v, t: t, m: m})
    end
  end

  defp timestamp, do: one_of([nil, DateTimeGenerator.date_time()])
  defp metadata, do: one_of([nil, map_of(string(:ascii), string(:ascii))])
end
