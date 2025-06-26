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

defmodule Astarte.Core.Generators.Triggers.Policy.Handler do
  @moduledoc """
  This module provides generators for Astarte Trigger Policy Handler.
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Core.Generators.Triggers.Policy.ErrorType, as: ErrorTypeGenerator
  alias Astarte.Core.Triggers.Policy.Handler

  @doc """
  Generates a valid Astarte Triggers Policy Handler from scratch
  """
  @spec handler() :: StreamData.t(Handler.t())
  @spec handler(params :: keyword()) :: StreamData.t(Handler.t())
  def handler(params \\ []) do
    params gen all strategy <- strategy(),
                   on <- ErrorTypeGenerator.error_type(),
                   params: params do
      %Handler{
        strategy: strategy,
        on: on
      }
    end
  end

  @doc """
  Convert this struct stream to changes
  """
  @spec to_changes(StreamData.t(Handler.t())) :: StreamData.t(map())
  def to_changes(gen) do
    gen all %Handler{
              strategy: strategy,
              on: error
            } <- gen,
            on <-
              ErrorTypeGenerator.error_type(error: error) |> ErrorTypeGenerator.to_changes() do
      %{
        strategy: strategy,
        on: on
      }
    end
  end

  defp strategy, do: member_of(["discard", "retry"])
end
