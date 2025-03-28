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
  alias Astarte.Core.Triggers.Policy.ErrorRange

  use ExUnitProperties

  @doc """
  Generates a valid Astarte Triggers Policy ErrorRange from scratch
  TODO: using `ecto_stream_factory` in the future
  """
  @spec error_range() :: StreamData.t(ErrorRange.t())
  def error_range do
    gen all error_codes <- error_codes() do
      %ErrorRange{
        error_codes: error_codes
      }
    end
  end

  defp error_codes do
    one_of([
      integer(400..599),
      list_of(integer(400..599), min_length: 1)
    ])
  end
end
