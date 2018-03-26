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

defmodule Astarte.TriggerEngine.Templating.HeadersTemplate do
  alias Astarte.TriggerEngine.Templating.HeadersTemplate

  defstruct [
    :headers
  ]

  def new(headers) do
    Map.put(%HeadersTemplate{}, :headers, headers)
  end

  def apply(template) do
    template.headers
  end

  def merge(template, vars) do
    Enum.reduce(vars, template, fn {var_key, var_value}, template_acc ->
      put(template_acc, var_key, var_value)
    end)
  end

  def put(template, var_key, var_value) when is_binary(var_value) do
    new_headers =
      Enum.map(template.headers, fn entry ->
        String.replace(entry, "%{#{var_key}}", var_value)
      end)

    Map.put(template, :headers, new_headers)
  end

  def put(template, var_key, var_value) do
    template
  end
end
