# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.ValueMatchOperators do
  def value_matches?(_received_value, :ANY, _known_value) do
    true
  end

  def value_matches?(nil, _OPERATOR, _known_value) do
    false
  end

  def value_matches?(received_value, :EQUAL_TO, known_value) do
    received_value == known_value
  end

  def value_matches?(received_value, :NOT_EQUAL_TO, known_value) do
    received_value != known_value
  end

  def value_matches?(received_value, :GREATER_THAN, known_value) do
    received_value > known_value
  end

  def value_matches?(received_value, :GREATER_OR_EQUAL_TO, known_value) do
    received_value >= known_value
  end

  def value_matches?(received_value, :LESS_THAN, known_value) do
    received_value < known_value
  end

  def value_matches?(received_value, :LESS_OR_EQUAL_TO, known_value) do
    received_value <= known_value
  end

  def value_matches?(received_value, :CONTAINS, known_value) when is_binary(received_value) do
    String.contains?(received_value, known_value)
  end

  def value_matches?(received_value, :CONTAINS, known_value) when is_list(received_value) do
    Enum.member?(received_value, known_value)
  end

  def value_matches?(_received_value, :CONTAINS, _known_value) do
    false
  end

  def value_matches?(received_value, :NOT_CONTAINS, known_value) when is_binary(received_value) do
    not String.contains?(received_value, known_value)
  end

  def value_matches?(received_value, :NOT_CONTAINS, known_value) when is_list(received_value) do
    not Enum.member?(received_value, known_value)
  end

  def value_matches?(_received_value, :NOT_CONTAINS, _known_value) do
    false
  end
end
