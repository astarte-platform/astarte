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

defmodule Astarte.TriggerEngine.HttpRequest do
  alias Astarte.TriggerEngine.HttpRequest
  alias Astarte.TriggerEngine.Templating.HeadersTemplate
  alias Astarte.TriggerEngine.Templating.StructTemplate
  alias Astarte.TriggerEngine.Templating.TextTemplate
  alias Astarte.TriggerEngine.Templating.URLTemplate

  defstruct [
    :method,
    :url,
    :headers,
    :body
  ]

  def build_http_request(template, vars) do
    IO.puts(inspect(template.url))

    %HttpRequest{
      method: template.method,
      url: template.url |> URLTemplate.merge(vars) |> URLTemplate.apply(),
      headers: template.headers |> HeadersTemplate.merge(vars) |> HeadersTemplate.apply(),
      body: build_body(template.body, vars, template.body_type)
    }
  end

  defp build_body(template, vars, :json) do
    template
    |> StructTemplate.merge(vars)
    |> StructTemplate.apply()
    |> Poison.encode!()
  end

  defp build_body(template, vars, :text) do
    template
    |> TextTemplate.merge(vars)
    |> TextTemplate.apply()
  end

  defp build_body(_template, _vars, :no_body) do
    nil
  end
end
