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

defmodule Astarte.Generators.Utilities do
  @moduledoc """
  Provides a helper function `print/2` that wraps the output of a StreamData generator
  with optional `:pre` and `:post` strings, producing a new generator of `String.t()`.
  """
  use ExUnitProperties

  @spec print(StreamData.t(term()), Keyword.t()) :: StreamData.t(String.t())
  @spec print(StreamData.t(term())) :: StreamData.t(String.t())
  def print(generator, opts \\ []) do
    pre = Keyword.get(opts, :pre, "")
    post = Keyword.get(opts, :post, "")

    gen all data <- generator do
      "#{pre}#{data}#{post}"
    end
  end
end
