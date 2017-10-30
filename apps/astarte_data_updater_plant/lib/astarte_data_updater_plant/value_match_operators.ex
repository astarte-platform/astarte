#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.ValueMatchOperators do

  def value_matches?(_received_value, :ANY, _known_value) do
    true
  end

  def value_matches?(received_value, :EQUAL, known_value) do
    received_value == known_value
  end

  def value_matches?(received_value, :NOT_EQUAL, known_value) do
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

end
