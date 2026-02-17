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

defmodule Astarte.Cases.Policy do
  @moduledoc """
  ExUnit case template for policy tests.
  """

  use ExUnit.CaseTemplate

  alias Astarte.Core.Generators.Triggers.Policy

  setup do
    realm_name = "realm#{System.unique_integer([:positive])}"
    policy = Policy.policy() |> Enum.at(0)

    %{realm_name: realm_name, policy: policy}
  end
end
