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

defmodule Astarte.DataUpdaterPlant.DataTrigger do
  @enforce_keys [:trigger_targets]
  defstruct [
    :path_match_tokens,
    :value_match_operator,
    :known_value,
    :trigger_targets
  ]

  def are_congruent?(trigger_a, trigger_b) do
    (trigger_a.path_match_tokens == trigger_b.path_match_tokens) and
    (trigger_a.value_match_operator == trigger_b.value_match_operator) and
    (trigger_a.known_value == trigger_b.known_value)
  end

end
