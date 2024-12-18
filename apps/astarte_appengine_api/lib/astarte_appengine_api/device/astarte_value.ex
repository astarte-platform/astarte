# Copyright 2018-2021 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Astarte.AppEngine.API.Device.AstarteValue do
  # Match on nil values, skipping any conversion. This is needed to handle missing endpoints in
  # object aggregations, which are allowed due to semantic versioning (i.e. data sent from a
  # previous minor version doesn't contain data on new endpoints)
  def to_json_friendly(nil, _value_type, _opts) do
    nil
  end

  # Allow :null values, converting them to `nil`. See comment above.
  def to_json_friendly(:null, _value_type, _opts) do
    nil
  end

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

  def to_json_friendly(value, _value_type, _opts) do
    value
  end
end
