#
# This file is part of Astarte.
#
# Copyright 2018 - 2023 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder do
  require Logger
  alias Astarte.Core.Interface

  @max_uncompressed_payload_size 10_485_760

  @doc """
  Decode a BSON payload a returns a tuple containing the decoded value, the timestamp and metadata.
  reception_timestamp is used if no timestamp has been sent with the payload.
  """
  @spec decode_bson_payload(binary, integer) :: {map, integer, map}
  def decode_bson_payload(payload, reception_timestamp) do
    if byte_size(payload) != 0 do
      case Cyanide.decode(payload) do
        {:ok, %{"v" => bson_value, "t" => %DateTime{} = timestamp, "m" => %{} = metadata}} ->
          bson_timestamp = DateTime.to_unix(timestamp, :millisecond)
          {bson_value, bson_timestamp, metadata}

        {:ok, %{"v" => bson_value, "m" => %{} = metadata}} ->
          {bson_value, div(reception_timestamp, 10000), metadata}

        {:ok, %{"v" => bson_value, "t" => %DateTime{} = timestamp}} ->
          bson_timestamp = DateTime.to_unix(timestamp, :millisecond)
          {bson_value, bson_timestamp, %{}}

        {:ok, %{"v" => %Cyanide.Binary{data: <<>>}}} ->
          {nil, nil, nil}

        {:ok, %{"v" => bson_value}} ->
          {bson_value, div(reception_timestamp, 10000), %{}}

        {:ok, %{} = bson_value} ->
          # Handling old format object aggregation
          {bson_value, div(reception_timestamp, 10000), %{}}

        {:error, _reason} ->
          {:error, :undecodable_bson_payload}

        _ ->
          {:error, :undecodable_bson_payload}
      end
    else
      {nil, nil, nil}
    end
  end

  @doc """
  Safely decodes a zlib deflated binary and inflates it.
  This function avoids zip bomb vulnerabilities, and it decodes up to 10_485_760 bytes.
  """
  @spec safe_inflate(binary) :: {:ok, binary} | :error
  def safe_inflate(zlib_payload) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)

    {continue_flag, output_list} = :zlib.safeInflate(z, zlib_payload)

    uncompressed_size =
      List.foldl(output_list, 0, fn output_block, acc ->
        acc + byte_size(output_block)
      end)

    inflated_result =
      if uncompressed_size < @max_uncompressed_payload_size do
        output_acc =
          List.foldl(output_list, <<>>, fn output_block, acc ->
            acc <> output_block
          end)

        safe_inflate_loop(z, output_acc, uncompressed_size, continue_flag)
      else
        :error
      end

    :zlib.inflateEnd(z)
    :zlib.close(z)

    inflated_result
  catch
    # :zlib functions might throw errors, catch them so we do not crash
    :error, error ->
      _ =
        Logger.warning("Received invalid deflated zlib payload: #{inspect(error)}",
          tag: "inflate_fail"
        )

      :error
  end

  defp safe_inflate_loop(z, output_acc, size_acc, :continue) do
    {continue_flag, output_list} = :zlib.safeInflate(z, [])

    uncompressed_size =
      List.foldl(output_list, size_acc, fn output_block, acc ->
        acc + byte_size(output_block)
      end)

    if uncompressed_size < @max_uncompressed_payload_size do
      output_acc =
        List.foldl(output_list, output_acc, fn output_block, acc ->
          acc <> output_block
        end)

      safe_inflate_loop(z, output_acc, uncompressed_size, continue_flag)
    else
      :error
    end
  end

  defp safe_inflate_loop(_z, output_acc, _size_acc, :finished) do
    {:ok, output_acc}
  end

  @doc """
  Decodes a properties paths list and returning a MapSet with them.
  """
  @spec parse_device_properties_payload(String.t(), map) ::
          {:ok, MapSet.t(String.t())} | {:error, :invalid_properties}

  def parse_device_properties_payload("", _introspection) do
    {:ok, MapSet.new()}
  end

  def parse_device_properties_payload(decoded_payload, introspection) do
    if String.valid?(decoded_payload) do
      parse_device_properties_string(decoded_payload, introspection)
    else
      {:error, :invalid_properties}
    end
  end

  def parse_device_properties_string(decoded_payload, introspection) do
    paths_list =
      decoded_payload
      |> String.split(";")
      |> List.foldl(MapSet.new(), fn property_full_path, paths_acc ->
        with [interface, path] <- String.split(property_full_path, "/", parts: 2) do
          if Map.has_key?(introspection, interface) do
            MapSet.put(paths_acc, {interface, "/" <> path})
          else
            paths_acc
          end
        else
          _ ->
            # TODO: we should print a warning, or return a :issues_found status
            paths_acc
        end
      end)

    {:ok, paths_list}
  end

  @doc """
  Decodes introspection string into a list of tuples
  """
  @spec parse_introspection(String.t()) ::
          {:ok, list({String.t(), integer, integer})} | {:error, :invalid_introspection}
  def parse_introspection("") do
    {:ok, []}
  end

  def parse_introspection(introspection_payload) do
    if String.valid?(introspection_payload) do
      parse_introspection_string(introspection_payload)
    else
      {:error, :invalid_introspection}
    end
  end

  defp parse_introspection_string(introspection_payload) do
    introspection_tokens = String.split(introspection_payload, ";")

    all_tokens_are_good =
      Enum.all?(introspection_tokens, fn token ->
        with [interface_name, major_version_string, minor_version_string] <-
               String.split(token, ":"),
             {major_version, ""} <- Integer.parse(major_version_string),
             {minor_version, ""} <- Integer.parse(minor_version_string) do
          cond do
            String.match?(interface_name, Interface.interface_name_regex()) == false ->
              false

            major_version < 0 ->
              false

            minor_version < 0 ->
              false

            true ->
              true
          end
        else
          _not_expected ->
            false
        end
      end)

    if all_tokens_are_good do
      parsed_introspection =
        for token <- introspection_tokens do
          [interface_name, major_version_string, minor_version_string] = String.split(token, ":")

          {major_version, ""} = Integer.parse(major_version_string)
          {minor_version, ""} = Integer.parse(minor_version_string)

          {interface_name, major_version, minor_version}
        end

      {:ok, parsed_introspection}
    else
      {:error, :invalid_introspection}
    end
  end
end
