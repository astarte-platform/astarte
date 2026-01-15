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

defmodule Astarte.Core.Generators.Realm do
  @moduledoc """
  Astarte Realm generators.
  """
  use ExUnitProperties

  alias Astarte.Core.Realm

  @doc """
  Generates a random Realm name.
  Follow the link to see valid Realm names:
  https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/realm.ex
  """
  @spec realm_name() :: StreamData.t(String.t())
  def realm_name do
    gen all(
          first <- string([?a..?z], length: 1),
          rest <- string([?a..?z, ?0..?9], length: 0..47)
        ) do
      first <> rest
    end
    |> filter(&valid?/1)
  end

  defp valid?(name), do: Realm.valid_name?(name)
end
