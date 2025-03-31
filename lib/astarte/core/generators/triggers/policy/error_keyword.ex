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

defmodule Astarte.Core.Generators.Triggers.Policy.ErrorKeyword do
  @moduledoc """
  This module provides generators for Astarte Trigger Policy ErrorKeyword.
  """
  alias Astarte.Core.Triggers.Policy.ErrorKeyword

  use ExUnitProperties

  @doc """
  Generates a valid Astarte Triggers Policy ErrorKeyword from scratch
  """
  @spec error_keyword() :: StreamData.t(ErrorKeyword.t())
  def error_keyword do
    gen all keyword <- keyword() do
      %ErrorKeyword{
        keyword: keyword
      }
    end
  end

  defp keyword do
    member_of([
      "client_error",
      "server_error",
      "any_error"
    ])
  end
end
