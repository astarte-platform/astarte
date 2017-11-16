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

defmodule Astarte.TriggerEngine.Templating.URLTemplate do
  alias Astarte.TriggerEngine.Templating.URLTemplate

  defstruct [
    :url
  ]

  def new(url) do
    %URLTemplate{url: url}
  end

  def apply(template) do
    template.url
  end

  def merge(template, vars) do
    Enum.reduce(vars, template, fn({var_key, var_value}, template_acc) ->
      put(template_acc, var_key, var_value)
    end)
  end

  def put(template, var_key, var_value) when is_binary(var_value) do
    replaced_url = String.replace(template.url, "%{#{var_key}}", var_value)
    Map.put(template, :url, replaced_url)
  end

  def put(template, _var_key, _var_value) do
    template
  end

end

