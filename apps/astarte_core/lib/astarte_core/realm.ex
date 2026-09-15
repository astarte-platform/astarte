#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Core.Realm do
  @moduledoc """
  Functions that deal with Astarte realms
  """

  @realm_regex ~r/^[a-z][a-z0-9]{0,47}$/

  @doc """
  Returns true if `realm_name` is a valid realm name, false otherwise.

  Valid realm names match this regular expression: `#{inspect(@realm_regex)}`.
  In addition, the `astarte` and `system` names and the `system_` prefix are reserved.
  """
  def valid_name?("astarte") do
    false
  end

  def valid_name?("system") do
    false
  end

  def valid_name?("system_" <> _rest) do
    false
  end

  def valid_name?(realm_name) do
    String.match?(realm_name, @realm_regex)
  end
end
