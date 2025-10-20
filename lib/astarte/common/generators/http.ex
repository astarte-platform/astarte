#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Common.Generators.HTTP do
  @moduledoc """
  Generators for HTTP related utilities
  https://datatracker.ietf.org/doc/html/rfc3986#section-1.1.2

  The scheme and path components are required, though the path may be
  empty (no characters).  When authority is present, the path must
  either be empty or begin with a slash ("/") character.  When
  authority is not present, the path cannot begin with two slash
  characters ("//").  These restrictions result in five different ABNF
  rules for a path (Section 3.3), only one of which will match any
  given URI reference.

  foo://example.com:8042/over/there?name=ferret#nose
    |           |            |            |        |
  scheme     authority       path        query   fragment
    |   _____________________|__
  """

  use Astarte.Generators.Utilities.ParamsGen

  alias Astarte.Common.Generators.Ip, as: IpGenerator
  alias Astarte.Generators.Utilities

  @http_methods ~w(get head options trace put delete post patch connect)

  @hexdig [?a..?f, ?A..?F, ?0..?9]
  @unreserved [?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?., ?~]
  @sub_delims [?!, ?$, ?&, ?', ?(, ?), ?*, ?+, ?,, ?;, ?=]

  @userinfo_charset @unreserved ++ @sub_delims ++ [?:]
  @reg_name_charset @unreserved ++ @sub_delims

  @pchar_charset @unreserved ++ @sub_delims ++ [?:, ?@]

  @query_charset @pchar_charset ++ [??, ?/]
  @fragment_charset @pchar_charset ++ [??, ?/]

  @path_charset @unreserved ++ @sub_delims ++ [?:, ?@]

  @doc """
  Generator for a valid port
  """
  @spec valid_port() :: StreamData.t(integer())
  def valid_port, do: integer(0..65_535)

  @doc """
  Generator for HTTP methods
  """
  @spec method() :: StreamData.t(String.t())
  def method, do: member_of(@http_methods)

  @doc """
  Valid http or https url as per RFC 3986
  """
  @spec url() :: StreamData.t(String.t())
  @spec url(params :: keyword()) :: StreamData.t(String.t())
  def url(params \\ []) do
    params gen all schema <- schema(),
                   user_info <- user_info(),
                   host <- host(),
                   port <- port(),
                   path <- path(),
                   query <- query(),
                   fragment <- fragment(),
                   params: params do
      schema <> "://" <> user_info <> host <> port <> path <> query <> fragment
    end
  end

  defp schema, do: member_of(["http", "https"])

  defp user_info do
    one_of([
      mixed(@userinfo_charset, min_length: 1) |> Utilities.print(post: "@"),
      constant("")
    ])
  end

  defp host do
    one_of([
      ipv4(),
      # TODO `URI.new` does not yet implement ip_literal
      # ip_literal(),
      reg_name()
    ])
  end

  defp port do
    one_of([
      valid_port() |> Utilities.print(pre: ":"),
      constant("")
    ])
  end

  defp ipv4 do
    IpGenerator.ip(:ipv4) |> map(fn {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}" end)
  end

  # TODO section: `URL.new` does not yet implement ip_literal
  # defp ip_literal do
  #   one_of([
  #     ipv6(),
  #     ip_v_future()
  #   ])
  #   |> Utilities.print(pre: "[", post: "]")
  # end

  # defp ipv6 do
  #   IpGenerator.ip(:ipv6) |> map(fn {a, b, c, d, e, f} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}" end)
  # end

  # defp ip_v_future do
  #   gen all version <- string(@hexdig, min_length: 1),
  #           address <- string(@userinfo_charset, min_length: 1) do
  #     "v" <> version <> "." <> address
  #   end
  # end

  defp reg_name do
    mixed(@reg_name_charset)
  end

  defp path do
    one_of([
      path_abempty(),
      path_absolute(),
      path_rootless(),
      path_empty()
    ])
  end

  defp path_abempty do
    segment()
    |> map(fn segment -> "/" <> segment end)
    |> list_of()
    |> map(&Enum.join/1)
  end

  defp path_absolute do
    path_rootless()
    |> map(fn path -> "/" <> path end)
  end

  defp path_rootless do
    gen all first_segment <- segment_nz(),
            rest <- path_abempty() do
      "/" <> first_segment <> rest
    end
  end

  defp path_empty, do: constant("")

  defp segment, do: mixed(@path_charset)

  defp segment_nz, do: mixed(@path_charset, min_length: 1)

  defp query do
    one_of([
      mixed(@query_charset, min_length: 1) |> Utilities.print(pre: "?"),
      constant("")
    ])
  end

  defp fragment do
    one_of([
      mixed(@fragment_charset, min_length: 1) |> Utilities.print(pre: "#"),
      constant("")
    ])
  end

  #
  # Utilities section
  #
  defp pct_encoded do
    string(@hexdig, length: 2)
    |> map(fn hex -> "%" <> hex end)
  end

  defp mixed(type, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 0)

    [string(type, min_length: 1, max_length: 16), pct_encoded()]
    |> one_of()
    |> list_of(min_length: min_length)
    |> map(&Enum.join/1)
  end
end
