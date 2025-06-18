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

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorTypeTest do
  @moduledoc """
  Tests for Astarte Triggers Policy ErrorType generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Triggers.Policy.ErrorType, as: ErrorTypeGenerator
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange

  @moduletag :trigger
  @moduletag :policy
  @moduletag :error_type

  defp valid_error_type?(%ErrorKeyword{} = _error_type), do: true
  defp valid_error_type?(%ErrorRange{} = _error_type), do: true
  defp valid_error_type?(_error_type), do: false

  @doc false
  describe "triggers policy error_type generator" do
    @describetag :success
    @describetag :ut

    property "validate triggers policy error_type" do
      check all error_type <- ErrorTypeGenerator.error_type() do
        assert valid_error_type?(error_type)
      end
    end
  end
end
