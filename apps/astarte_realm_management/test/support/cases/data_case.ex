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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the application
  database.

  You may define functions here to be used as helpers in your tests.
  """

  use ExUnit.CaseTemplate
  import Astarte.Test.Helpers.Database

  using do
    quote do
      import Astarte.RealmManagement.DataCase
      import Astarte.Test.Helpers.Database
    end
  end

  setup do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    setup!(realm)
    insert_public_key!(realm)

    on_exit(fn ->
      teardown!(realm)
    end)

    %{realm: realm}
  end
end
