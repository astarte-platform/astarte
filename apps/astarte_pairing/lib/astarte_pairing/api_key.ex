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

defmodule Astarte.Pairing.APIKey do
  @moduledoc """
  This module is responsible for generating and verifying the APIKeys for the
  pairing authentication
  """

  alias Astarte.Pairing.Config
  alias Plug.Crypto.KeyGenerator

  @doc """
  Generates an API key starting from a realm and a device_uuid.

  The key is signed using a secret derived from the base secret and the
  salt passed in the function.

  Returns the generated API key.
  """
  def generate(realm, device_uuid, salt) do
    secret = get_secret(salt)

    api_key =
      device_uuid <> realm
      |> MessageVerifier.sign(secret)

    {:ok, api_key}
  end

  defp get_secret(salt) do
    Config.secret_key_base()
    |> KeyGenerator.generate(salt)
  end
end
