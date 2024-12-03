# Copyright 2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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
#

defmodule Astarte.Import.LogFmtFormatter do
  epoch = {{1970, 1, 1}, {0, 0, 0}}
  @epoch :calendar.datetime_to_gregorian_seconds(epoch)

  def format(level, message, timestamp, metadata) do
    {date, {h, m, s, millis}} = timestamp

    pre_message_metadata = Application.get_env(:logfmt, :prepend_metadata, [])

    {pre_meta, metadata} = Keyword.split(metadata, pre_message_metadata)

    unless Application.get_env(:logfmt, :user_friendly, false) do
      timestamp =
        :erlang.localtime_to_universaltime({date, {h, m, s}})
        |> :calendar.datetime_to_gregorian_seconds()
        |> Kernel.-(@epoch)

      timestamp_string =
        (timestamp * 1000 + millis)
        |> :calendar.system_time_to_rfc3339(unit: :millisecond)
        |> to_string()

      kv =
        sanitize_keyword(
          [ts: timestamp_string, level: level] ++ pre_meta ++ [message: message] ++ metadata
        )

      [Logfmt.encode(kv), "\n"]
    else
      time_string = "#{to_string(h)}:#{to_string(m)}:#{to_string(s)}.#{to_string(millis)}"

      level_string =
        level
        |> sanitize()
        |> String.upcase()
        |> String.pad_trailing(5)

      padded_message =
        message
        |> sanitize()
        |> String.pad_trailing(48)

      encoded_metadata =
        (pre_meta ++ metadata)
        |> sanitize_keyword()
        |> Logfmt.encode()

      "#{time_string}\t|#{level_string}| #{padded_message}\t| #{encoded_metadata}\n"
    end
  rescue
    _ -> "LOGGING_ERROR: #{inspect({level, message, metadata})}\n"
  end

  defp sanitize_keyword(keywords) do
    Enum.map(keywords, fn {k, v} ->
      {k, sanitize(v)}
    end)
  end

  defp sanitize(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp sanitize(value) when is_binary(value) do
    Logger.Formatter.prune(value)
  end

  defp sanitize(value) when is_list(value) do
    value
    |> Logger.Formatter.prune()
    |> :erlang.iolist_to_binary()
  rescue
    _ ->
      value
      |> :erlang.term_to_binary()
      |> Base.encode64()
  end

  defp sanitize(value) do
    value
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end
end
