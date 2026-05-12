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

defmodule Astarte.Core.Group do
  @moduledoc """
  Functions that deal with Astarte groups
  """

  @doc """
  Returns true if `group_name` is a valid group name, false otherwise.

  Valid group names _do not_ start with reserved characters `@` and `~`.
  """
  def valid_name?("") do
    false
  end

  def valid_name?("~" <> _rest) do
    false
  end

  def valid_name?("@" <> _rest) do
    false
  end

  def valid_name?(_group_name) do
    true
  end
end
