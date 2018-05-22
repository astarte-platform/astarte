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

defmodule Astarte.AppEngine.API.Device.AstarteValue do
  def to_json_friendly(value, :longinteger, opts) do
    cond do
      opts[:allow_bigintegers] ->
        value

      opts[:allow_safe_bigintegers] ->
        # the following magic value is the biggest mantissa allowed in a double value
        if value <= 0xFFFFFFFFFFFFF do
          value
        else
          Integer.to_string(value)
        end

      true ->
        Integer.to_string(value)
    end
  end

  def to_json_friendly(value, :binaryblob, _opts) do
    Base.encode64(value)
  end

  def to_json_friendly(value, :datetime, opts) do
    if opts[:keep_milliseconds] do
      value
    else
      DateTime.from_unix!(value, :millisecond)
    end
  end

  def to_json_friendly(value, :longintegerarray, opts) do
    for item <- value do
      to_json_friendly(item, :longinteger, opts)
    end
  end

  def to_json_friendly(value, :binaryblobarray, _opts) do
    for item <- value do
      Base.encode64(item)
    end
  end

  def to_json_friendly(value, :datetimearray, opts) do
    for item <- value do
      to_json_friendly(item, :datetime, opts)
    end
  end

  def to_json_friendly(:null, _value_type, _opts) do
    raise ArgumentError, message: "invalid argument :null"
  end

  def to_json_friendly(nil, _value_type, _opts) do
    raise ArgumentError, message: "invalid nil argument"
  end

  def to_json_friendly(value, _value_type, _opts) do
    value
  end
end
