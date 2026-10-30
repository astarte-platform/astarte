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

defmodule Astarte.Auth.Config.OpenFGAStoreBinding do
  @moduledoc """
  Resolves the OpenFGA store id from the store name.
  """

  use Skogsra.Binding

  alias Astarte.Auth.Config
  alias Astarte.Auth.OpenFGA

  @impl Skogsra.Binding
  def get_env(_env, _config) do
    case Config.openfga_store_name() do
      {:ok, store_name} when store_name not in [nil, ""] -> OpenFGA.fetch_store_id(store_name)
      {:ok, _unset} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end
end
