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

defmodule Astarte.Pairing.TestHelper do
  @valid_fallback_api_key "validfallbackapikey"

  def random_hw_id do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def valid_fallback_api_key do
    @valid_fallback_api_key
  end

  def fallback_verify_key(@valid_fallback_api_key, _salt) do
    {:ok, "testrealm", :uuid.get_v4()}
  end

  def fallback_verify_key(_invalid_api_key, _salt) do
    {:error, :invalid_api_key}
  end
end
