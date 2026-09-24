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

defmodule Astarte.Common.Generators.UUID do
  @moduledoc """
  Generates RFC 4122 version 4 UUIDs in their raw binary representation.
  """
  use ExUnitProperties

  @typedoc "A raw RFC 4122 UUID."
  @type t :: <<_::128>>

  @doc """
  Generates a random RFC 4122 version 4 UUID.
  """
  @spec uuid() :: StreamData.t(t())
  def uuid do
    gen all binary <- binary(length: 16) do
      <<prefix::48, _version::4, middle::12, _variant::2, suffix::62>> = binary
      <<prefix::48, 4::4, middle::12, 2::2, suffix::62>>
    end
  end
end
