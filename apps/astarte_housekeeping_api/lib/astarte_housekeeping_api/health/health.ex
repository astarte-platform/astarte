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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.Housekeeping.API.Health do
  @moduledoc """
  Performs health checks of the Housekeeping service
  """

  alias Astarte.Housekeeping.API.Health.BackendHealth
  alias Astarte.Housekeeping.API.RPC.Housekeeping

  @doc """
  Gets the backend health. Returns `{:ok, %BackendHealth{}`
  """
  def get_backend_health do
    with {:ok, %{status: status}} <- Housekeeping.get_health() do
      {:ok, %BackendHealth{status: status}}
    else
      _ ->
        {:ok, %BackendHealth{status: :error}}
    end
  end
end
