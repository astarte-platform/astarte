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

defmodule Astarte.Cases.Cache do
  @moduledoc """
  Test case for modules relying on cache state.

  Ensures caches are cleaned up per realm.
  """

  use ExUnit.CaseTemplate

  alias Astarte.Events.Triggers.Cache

  using _opts do
    quote do
      import Astarte.Cases.Cache
    end
  end

  setup %{realm_name: realm} do
    on_exit(fn ->
      Cache.reset_realm_cache(realm)
    end)

    :ok
  end
end
