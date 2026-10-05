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

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorType do
  @moduledoc """
  This module provides generators for Astarte Trigger Policy ErrorType.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Triggers.Policy.ErrorKeyword
  import Astarte.Core.Generators.Triggers.Policy.ErrorRange

  alias Astarte.Core.Triggers.Policy.ErrorType

  @doc """
  Generates a valid Astarte Triggers Policy ErrorType from scratch
  """
  @spec error_type() :: StreamData.t(ErrorType.t())
  @spec error_type(params :: keyword()) :: StreamData.t(ErrorType.t())
  def error_type(params \\ []) do
    params gen all error <- [error_keyword(), error_range()] |> one_of(),
                   params: params do
      error
    end
  end
end
