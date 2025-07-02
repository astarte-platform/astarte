#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.RealmManagement.API.Triggers.HttpAction do
  use TypedEctoSchema
  import Ecto.Changeset
  alias Astarte.RealmManagement.API.Triggers.HttpAction

  @primary_key false
  typed_embedded_schema do
    field :http_url, :string
    field :http_method, :string
    field :http_static_headers, {:map, :string}

    field :template, :string
    field :template_type, :string

    field :http_post_url, :string, virtual: true
    field :ignore_ssl_errors, :boolean
  end

  @all_attrs [
    :http_url,
    :http_method,
    :http_static_headers,
    :template,
    :template_type,
    :http_post_url,
    :ignore_ssl_errors
  ]

  @valid_methods ["delete", "get", "head", "options", "patch", "post", "put"]

  @headers_blocklist MapSet.new([
                       "connection",
                       "content-length",
                       "date",
                       "host",
                       "te",
                       "upgrade",
                       "x-forwarded-for",
                       "x-forwarded-host",
                       "x-forwarded-proto",
                       "sec-websocket-accept",
                       "proxy-authorization",
                       "proxy-authenticate"
                     ])

  @max_headers_size 8192
  @max_url_length 8192

  @max_mustache_template_size 1024 * 1024

  @doc false
  def changeset(%HttpAction{} = action, %{"http_post_url" => _post_url} = attrs) do
    action
    |> cast(attrs, @all_attrs)
    |> validate_required([:http_post_url])
    |> validate_empty(:http_url)
    |> validate_empty(:http_method)
    |> validate_empty(:http_static_headers)
    |> validate_url(:http_post_url)
    |> validate_length(:template, max: @max_mustache_template_size)
    |> normalize_fields()
  end

  @doc false
  def changeset(%HttpAction{} = action, %{"http_url" => _url} = attrs) do
    action
    |> cast(attrs, @all_attrs)
    |> validate_required([:http_url, :http_method])
    |> validate_empty(:http_post_url)
    |> validate_url(:http_url)
    |> validate_inclusion(:http_method, @valid_methods)
    |> validate_headers(:http_static_headers)
    |> validate_headers_size(:http_static_headers)
    |> validate_length(:template, max: @max_mustache_template_size)
  end

  defp normalize_fields(changeset) do
    post_url = get_field(changeset, :http_post_url)

    changeset
    |> delete_change(:http_post_url)
    |> put_change(:http_url, post_url)
    |> put_change(:http_method, "post")
  end

  defp validate_empty(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn
      _field, nil -> []
      field, _ -> [{field, opts[:message] || "must be blank"}]
    end)
  end

  defp validate_url(changeset, field, opts \\ []) do
    validate_length(changeset, field, min: String.length("http://a"), max: @max_url_length)
    |> validate_change(field, fn field, value ->
      with %URI{scheme: scheme, host: host} <- URI.parse(value),
           true <- scheme == "http" or scheme == "https",
           true <- String.valid?(host),
           true <- String.length(host) > 0 do
        []
      else
        _any ->
          [{field, opts[:message] || "must be a valid http(s) URL"}]
      end
    end)
  end

  defp validate_headers(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn field, headers ->
      allowed = Enum.all?(headers, fn {header_name, _value} -> allowed_header?(header_name) end)

      if allowed do
        []
      else
        [{field, opts[:message] || "must contain only allowed http headers"}]
      end
    end)
  end

  defp allowed_header?(header_name) do
    normalized =
      header_name
      |> String.trim()
      |> String.downcase()

    MapSet.member?(@headers_blocklist, normalized) == false
  end

  defp validate_headers_size(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn field, headers ->
      size =
        Enum.reduce(headers, 0, fn {header_name, header_value}, acc ->
          acc + byte_size(header_name) + byte_size(": ") + byte_size(header_value)
        end)

      if size < @max_headers_size do
        []
      else
        [{field, opts[:message] || "headers total size must be lower than #{@max_headers_size}"}]
      end
    end)
  end
end
