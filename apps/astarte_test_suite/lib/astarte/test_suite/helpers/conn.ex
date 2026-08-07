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

defmodule Astarte.TestSuite.Helpers.Conn do
  @moduledoc false

  @spec setup(map()) :: no_return()
  def setup(context) do
    raise_not_implemented(context)
  end

  @spec data(map()) :: no_return()
  def data(context) do
    raise_not_implemented(context)
  end

  @spec raise_not_implemented(map()) :: no_return()
  defp raise_not_implemented(_context) do
    raise "not implemented yet"
  end
end
