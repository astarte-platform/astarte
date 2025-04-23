defmodule Astarte.Common.Generators.HTTP do
  @moduledoc """
    Generators for HTTP related utilities
  """

  use ExUnitProperties

  alias Astarte.Common.Generators.Ip

  @hexdig [?a..?f, ?A..?F, ?0..?9]
  @unreserved [?a..?z, ?A..?Z, ?0..?9, ?-, ?_, ?., ?~]
  @sub_delims [?!, ?$, ?&, ?', ?(, ?), ?*, ?+, ?,, ?;, ?=]

  @userinfo_charset @unreserved ++ @sub_delims ++ [?:]
  @reg_name_charset @unreserved ++ @sub_delims
  @query_charset @unreserved ++ @sub_delims ++ [?:, ?@, ??, ?/]
  @path_charset @unreserved ++ @sub_delims ++ [?:, ?@]

  @doc """
    Valid http or https url as per RFC 3986
  """
  @spec url() :: StreamData.t(String.t())
  def url do
    gen all scheme <- member_of(["http", "https"]),
            hier_part <- hier_part(),
            query <- optional_string(query(), pre: "?") do
      scheme <> "://" <> hier_part <> query
    end
  end

  defp hier_part do
    gen all authority <- authority(),
            path <- one_of([path_abempty(), path_absolute(), path_rootless(), path_empty()]) do
      authority <> path
    end
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
      first_segment <> rest
    end
  end

  defp path_empty, do: constant("")

  defp segment do
    string_or_pct_encoded(@path_charset)
  end

  defp segment_nz do
    nonempty_string_or_pct_encoded(@path_charset)
  end

  defp query do
    string_or_pct_encoded(@query_charset)
  end

  defp authority do
    gen all userinfo <- optional_string(userinfo(), post: "@"),
            host <- host(),
            port <- optional_string(port(), pre: ":") do
      userinfo <> host <> port
    end
  end

  defp userinfo do
    string_or_pct_encoded(@userinfo_charset)
  end

  defp reg_name do
    string_or_pct_encoded(@reg_name_charset)
  end

  defp host, do: one_of([ip_literal(), ipv4_address(), reg_name()])

  defp ipv4_address do
    Ip.ip(:ipv4)
    |> map(fn {fst, snd, thd, fth} ->
      "#{fst}.#{snd}.#{thd}.#{fth}"
    end)
  end

  defp ip_literal do
    formats = [
      # TODO: uncomment when implemented
      # Ip.ip(:ipv6),
      ip_v_future()
    ]

    gen all address <- one_of(formats) do
      "[" <> address <> "]"
    end
  end

  defp ip_v_future do
    gen all version <- string(@hexdig, min_length: 1),
            address <- string(@userinfo_charset, min_length: 1) do
      "v" <> version <> "." <> address
    end
  end

  defp port do
    string([?0..?9])
  end

  defp string_or_pct_encoded(kind_or_codepoints) do
    [string(kind_or_codepoints), pct_encoded()]
    |> one_of()
    |> list_of()
    |> map(&Enum.join/1)
  end

  defp nonempty_string_or_pct_encoded(kind_or_codepoints) do
    [string(kind_or_codepoints, min_length: 1), pct_encoded()]
    |> one_of()
    |> list_of(min_length: 1)
    |> map(&Enum.join/1)
  end

  defp pct_encoded do
    string([?0..?9, ?a..?f, ?A..?F], length: 2)
    |> map(fn hex -> "%" <> hex end)
  end

  defp optional_string(generator, opts) do
    generator =
      case Keyword.fetch(opts, :pre) do
        {:ok, pre} -> map(generator, fn gen -> pre <> gen end)
        :error -> generator
      end

    generator =
      case Keyword.fetch(opts, :post) do
        {:ok, post} -> map(generator, fn gen -> gen <> post end)
        :error -> generator
      end

    one_of([generator, constant("")])
  end
end
