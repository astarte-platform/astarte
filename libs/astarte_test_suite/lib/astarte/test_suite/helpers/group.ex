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

defmodule Astarte.TestSuite.Helpers.Group do
  @moduledoc false

  alias Astarte.TestSuite.CaseContext

  def init(context) do
    context
    |> CaseContext.require_keys!([:devices_registered?], :group_init)
    |> CaseContext.put_fixture(:group_init, %{group_storage_ready?: true})
  end

  def setup(context) do
    context
    |> CaseContext.require_keys!([:group_storage_ready?], :group_setup)
    |> CaseContext.put_fixture(:group_setup, %{groups_ready?: true})
  end
end
