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

defmodule Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder do
  @doc """
  Decode a BSON payload a returns a tuple containing the decoded value, the timestamp and metadata.
  reception_timestamp is used if no timestamp has been sent with the payload.
  """
  @spec decode_bson_payload(binary, integer) :: {map, integer, map}
  def decode_bson_payload(payload, reception_timestamp) do
    if byte_size(payload) != 0 do
      decoded_payload = Bson.decode(payload)

      case decoded_payload do
        %{v: bson_value, t: %Bson.UTC{ms: bson_timestamp}, m: %{} = metadata} ->
          {bson_value, bson_timestamp, metadata}

        %{v: bson_value, m: %{} = metadata} ->
          {bson_value, div(reception_timestamp, 10000), metadata}

        %{v: bson_value, t: %Bson.UTC{ms: bson_timestamp}} ->
          {bson_value, bson_timestamp, %{}}

        %{v: %Bson.Bin{bin: <<>>, subtype: 0}} ->
          {nil, nil, nil}

        %{v: bson_value} ->
          {bson_value, div(reception_timestamp, 10000), %{}}

        %{} = bson_value ->
          # Handling old format object aggregation
          {bson_value, div(reception_timestamp, 10000), %{}}

        _ ->
          :error
      end
    else
      {nil, nil, nil}
    end
  end
end
