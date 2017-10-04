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

defmodule Astarte.Pairing.Utils do
  @moduledoc """
  Utility functions container.
  """

  @doc """
  Decodes the base64 encoded extended id and returns the first 128 bits, which
  can be used as an UUID.

  Returns `{:ok, uuid}` or `{:error, :id_decode_failed}` if the decoding fails.
  """
  def extended_id_to_uuid(extended_id) do
    case Base.url_decode64(extended_id, padding: false) do
      {:ok, <<device_uuid :: binary-size(16), _rest :: binary>>} -> {:ok, device_uuid}
      _ -> {:error, :id_decode_failed}
    end
  end
end
