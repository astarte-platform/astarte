#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.TestSuiteTest.Cases.ParamsCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using opts do
    quote do
      import Astarte.TestSuite.CaseContext

      alias Astarte.TestSuiteTest.Cases.ParamsCase

      setup_all context do
        config = ParamsCase.validate_config!(unquote(opts))
        value = ParamsCase.value!(config)

        {:ok, put_case(context, :params_case, %{params_case_value: value})}
      end
    end
  end

  def validate_config!(config) do
    case Keyword.keyword?(config) do
      true -> config
      false -> raise ArgumentError, "ParamsCase expects a keyword list"
    end
  end

  def value!(config) do
    config
    |> Keyword.get(:value, 0)
    |> validate_value!()
  end

  defp validate_value!(value) when is_integer(value), do: value

  defp validate_value!(_value),
    do: raise(ArgumentError, "ParamsCase expects :value to be an integer")
end
