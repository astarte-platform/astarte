#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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

defmodule Astarte.Import do
  defmodule State do
    defstruct [
      :device_id,
      :connected,
      :interface,
      :path,
      :reception_timestamp,
      :chars_acc,
      :object_data,
      :current_object_item,
      :got_device_end_fun,
      :got_end_of_value_fun,
      :got_end_of_object_fun,
      :got_end_of_property_fun,
      :got_interface_fun,
      :got_path_fun,
      :got_path_end_fun,
      :data,
      :cert_aki,
      :cert_serial,
      :credentials_secret,
      :capabilities,
      :first_credentials_request,
      :first_registration,
      :last_connection,
      :last_credentials_request_ip,
      :last_disconnection,
      :last_seen_ip,
      :pending_empty_cache,
      aliases: %{},
      attributes: %{},
      introspection: %{},
      old_introspection: %{},
      total_received_msgs: 0,
      total_received_bytes: 0
    ]
  end

  def parse(xml, opts \\ []) do
    initial_data = Keyword.get(opts, :data)
    continuation_fun = Keyword.get(opts, :continuation_fun, :undefined)
    got_interface_fun = Keyword.get(opts, :got_interface_fun)
    got_end_of_value_fun = Keyword.get(opts, :got_end_of_value_fun)
    got_end_of_object_fun = Keyword.get(opts, :got_end_of_object_fun)
    got_end_of_property_fun = Keyword.get(opts, :got_end_of_property_fun)
    got_device_end_fun = Keyword.get(opts, :got_device_end_fun)
    got_path_fun = Keyword.get(opts, :got_path_fun)
    got_path_end_fun = Keyword.get(opts, :got_path_end_fun)

    state = %State{
      data: initial_data,
      got_interface_fun: got_interface_fun,
      got_path_fun: got_path_fun,
      got_path_end_fun: got_path_end_fun,
      got_end_of_value_fun: got_end_of_value_fun,
      got_end_of_object_fun: got_end_of_object_fun,
      got_end_of_property_fun: got_end_of_property_fun,
      got_device_end_fun: got_device_end_fun
    }

    xmerl_opts = [
      event_fun: &xml_event/3,
      continuation_fun: continuation_fun,
      event_state: state
    ]

    {:ok, state, _tail} = :xmerl_sax_parser.stream(xml, xmerl_opts)

    state.data
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"astarte"}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"devices"}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"device"}, attributes}, _loc, state) do
    with {:ok, device_id} <- fetch_attribute(attributes, ~c"device_id"),
         connected <- get_attribute(attributes, ~c"connected", "false"),
         {:ok, connected} <- to_boolean(connected) do
      %State{state | device_id: device_id, connected: connected}
    else
      {:error, _reason} ->
        throw({:error, :invalid_device_element})
    end
  end

  # TODO: right now only protocol revision 0 or 1 is supported
  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"protocol"}, attributes}, _loc, state) do
    with {:ok, revision} when revision == "0" or revision == "1" <-
           fetch_attribute(attributes, ~c"revision"),
         pending_empty_cache_string = get_attribute(attributes, ~c"pending_empty_cache", "false"),
         {:ok, pending_empty_cache} <- to_boolean(pending_empty_cache_string) do
      %State{state | pending_empty_cache: pending_empty_cache}
    else
      {:error, _reason} ->
        throw({:error, :invalid_protocol_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"registration"}, attr}, _loc, state) do
    with {:ok, credentials_secret} <- fetch_attribute(attr, ~c"credentials_secret"),
         {:ok, first_registration_string} <- fetch_attribute(attr, ~c"first_registration"),
         {:ok, first_registration, 0} <- DateTime.from_iso8601(first_registration_string) do
      %State{
        state
        | credentials_secret: credentials_secret,
          first_registration: first_registration
      }
    else
      {:error, _reason} ->
        throw({:error, :invalid_registration_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"credentials"}, attr}, _loc, state) do
    with inhibit_request_string = get_attribute(attr, ~c"inhibit_request", "false"),
         {:ok, false} <- to_boolean(inhibit_request_string),
         {:ok, cert_serial} <- fetch_attribute(attr, ~c"cert_serial"),
         {:ok, cert_aki} <- fetch_attribute(attr, ~c"cert_aki"),
         {:ok, first_credentials_string} <- fetch_attribute(attr, ~c"first_credentials_request"),
         {:ok, first_credentials_request, 0} <- DateTime.from_iso8601(first_credentials_string),
         {:ok, last_creds_ip_string} <- fetch_attribute(attr, ~c"last_credentials_request_ip"),
         last_creds_ip_charlist = String.to_charlist(last_creds_ip_string),
         {:ok, last_credentials_request_ip} <- :inet.parse_address(last_creds_ip_charlist) do
      %State{
        state
        | cert_serial: cert_serial,
          cert_aki: cert_aki,
          first_credentials_request: first_credentials_request,
          last_credentials_request_ip: last_credentials_request_ip
      }
    else
      {:error, _reason} ->
        throw({:error, :invalid_credentials_element})
    end
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"attributes"}, _attributes},
         _loc,
         state
       ) do
    state
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"attribute"}, attributes},
         _loc,
         state
       ) do
    with {:ok, name} <- fetch_attribute(attributes, ~c"name"),
         {:ok, value} <- fetch_attribute(attributes, ~c"value") do
      %State{attributes: attributes} = state

      %State{state | attributes: Map.merge(attributes, %{name => value})}
    else
      _any ->
        throw({:error, :invalid_attributes_element})
    end
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"aliases"}, _attributes},
         _loc,
         state
       ) do
    state
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"alias"}, attributes},
         _loc,
         state
       ) do
    with {:ok, name} <- fetch_attribute(attributes, ~c"name"),
         {:ok, as} <- fetch_attribute(attributes, ~c"as") do
      %State{aliases: aliases} = state
      %State{state | aliases: Map.merge(aliases, %{name => as})}
    else
      _any ->
        throw({:error, :invalid_aliases_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"capabilities"}, attr}, _loc, state) do
    with {:ok, purge_properties_compression_format} <-
           fetch_attribute(attr, ~c"purge_properties_compression_format"),
         {purge_properties_compression_format, ""} <-
           Integer.parse(purge_properties_compression_format) do
      %State{
        state
        | capabilities: %{
            "purge_properties_compression_format" => purge_properties_compression_format
          }
      }
    else
      {:error, _reason} ->
        throw({:error, :invalid_capabilities_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"stats"}, attributes}, _loc, state) do
    with total_received_msgs_string = get_attribute(attributes, ~c"total_received_msgs", "0"),
         {total_received_msgs, ""} <- Integer.parse(total_received_msgs_string),
         total_received_bytes_string = get_attribute(attributes, ~c"total_received_bytes", "0"),
         {total_received_bytes, ""} <- Integer.parse(total_received_bytes_string),
         last_connection_string = get_attribute(attributes, ~c"last_connection", nil),
         {:ok, last_connection, 0} <- to_date_or_nil(last_connection_string),
         last_disconnection_string = get_attribute(attributes, ~c"last_disconnection", nil),
         {:ok, last_disconnection, 0} <- to_date_or_nil(last_disconnection_string),
         last_seen_ip_string = get_attribute(attributes, ~c"last_seen_ip", nil),
         {:ok, last_seen_ip} <- to_ip_or_nil(last_seen_ip_string) do
      %State{
        state
        | total_received_msgs: total_received_msgs,
          total_received_bytes: total_received_bytes,
          last_connection: last_connection,
          last_disconnection: last_disconnection,
          last_seen_ip: last_seen_ip
      }
    else
      {:error, _reason} ->
        throw({:error, :invalid_stats_element})
    end
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"interfaces"}, _attributes},
         _loc,
         state
       ) do
    state
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"interface"}, attributes},
         _loc,
         state
       ) do
    with {:ok, name} <- fetch_attribute(attributes, ~c"name"),
         {:ok, major_string} <- fetch_attribute(attributes, ~c"major_version"),
         {major, ""} <- Integer.parse(major_string),
         {:ok, minor_string} <- fetch_attribute(attributes, ~c"minor_version"),
         {minor, ""} <- Integer.parse(minor_string) do
      %State{
        introspection: introspection,
        old_introspection: old_introspection
      } = state

      {introspection, old_introspection} =
        case get_attribute(attributes, ~c"active") do
          "true" ->
            unless Map.has_key?(introspection, name) do
              {Map.put(introspection, name, {major, minor}), old_introspection}
            else
              throw({:error, :invalid_interface})
            end

          "false" ->
            unless Map.has_key?(old_introspection, {name, major}) do
              {introspection, Map.put(old_introspection, {name, major}, minor)}
            else
              throw({:error, :invalid_interface})
            end

          _ ->
            throw({:error, :invalid_interface})
        end

      state = %State{
        state
        | interface: {name, major, minor},
          introspection: introspection,
          old_introspection: old_introspection
      }

      case state do
        %State{got_interface_fun: nil} ->
          state

        %State{got_interface_fun: got_interface_fun} ->
          got_interface_fun.(state, name, major, minor)
      end
    else
      _any ->
        throw({:error, :invalid_interface})
    end
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, ~c"datastream"}, attributes},
         _loc,
         state
       ) do
    {:ok, path} = fetch_attribute(attributes, ~c"path")

    state = %State{state | path: path}

    case state do
      %State{got_path_fun: nil} ->
        state

      %State{got_path_fun: got_path_fun} ->
        got_path_fun.(state, path)
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"value"}, attributes}, _loc, state) do
    {:ok, reception_timestamp} = fetch_attribute(attributes, ~c"reception_timestamp")
    {:ok, datetime, 0} = DateTime.from_iso8601(reception_timestamp)

    %State{state | reception_timestamp: datetime}
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"object"}, attributes}, _loc, state) do
    {:ok, reception_timestamp} = fetch_attribute(attributes, ~c"reception_timestamp")
    {:ok, datetime, 0} = DateTime.from_iso8601(reception_timestamp)

    %State{state | reception_timestamp: datetime, object_data: %{}}
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"item"}, attributes}, _loc, state) do
    with {:ok, item_name} <- fetch_attribute(attributes, ~c"name") do
      %State{state | current_object_item: item_name}
    else
      _any ->
        throw({:error, :invalid_object_item})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, ~c"property"}, attributes}, _loc, state) do
    with {:ok, path} <- fetch_attribute(attributes, ~c"path"),
         {:ok, reception_timestamp} <- fetch_attribute(attributes, ~c"reception_timestamp"),
         {:ok, datetime, 0} <- DateTime.from_iso8601(reception_timestamp) do
      %State{state | path: path, reception_timestamp: datetime}
    else
      _any ->
        throw({:error, :invalid_property})
    end
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"property"}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      got_end_of_property_fun: got_end_of_property_fun
    } = state

    normalized_chars = normalize(chars_acc)
    state = got_end_of_property_fun.(state, normalized_chars)

    %State{state | chars_acc: nil, reception_timestamp: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"item"}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      object_data: object_data,
      current_object_item: current_object_item
    } = state

    normalized_chars = normalize(chars_acc)

    object_data = Map.put(object_data, current_object_item, normalized_chars)

    %State{state | chars_acc: nil, object_data: object_data, current_object_item: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"object"}}, _loc, state) do
    %State{
      object_data: object_data,
      got_end_of_object_fun: got_end_of_object_fun
    } = state

    state = got_end_of_object_fun.(state, object_data)

    %State{state | reception_timestamp: nil, object_data: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"value"}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      got_end_of_value_fun: got_end_of_value_fun
    } = state

    state = got_end_of_value_fun.(state, chars_acc)

    %State{state | chars_acc: nil, reception_timestamp: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"datastream"}}, _loc, state) do
    state =
      case state do
        %State{got_path_end_fun: nil} ->
          state

        %State{got_path_end_fun: got_path_end_fun} ->
          got_path_end_fun.(state)
      end

    %State{state | path: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"interface"}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"interfaces"}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"protocol"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"attributes"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"attribute"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"aliases"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"alias"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"capabilities"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"registration"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"credentials"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"stats"}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"device"}}, _loc, state) do
    state =
      case state do
        %State{got_device_end_fun: nil} ->
          state

        %State{got_device_end_fun: got_device_end_fun} ->
          got_device_end_fun.(state)
      end

    %State{
      state
      | cert_aki: nil,
        cert_serial: nil,
        aliases: nil,
        attributes: nil,
        capabilities: nil,
        credentials_secret: nil,
        first_credentials_request: nil,
        first_registration: nil,
        last_connection: nil,
        last_credentials_request_ip: nil,
        last_disconnection: nil,
        last_seen_ip: nil,
        pending_empty_cache: nil,
        introspection: %{},
        old_introspection: %{},
        total_received_msgs: 0,
        total_received_bytes: 0
    }
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"devices"}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, ~c"astarte"}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:characters, chars}, _loc, state) do
    case state do
      %State{chars_acc: nil} ->
        %State{state | chars_acc: chars}
    end
  end

  defp xml_event({:ignorableWhitespace, _whitespace}, _location, state) do
    state
  end

  defp xml_event(:startDocument, _location, state) do
    state
  end

  defp xml_event(:endDocument, _location, state) do
    state
  end

  defp xml_event({:comment, _comment_data}, _loc, state) do
    state
  end

  defp xml_event(event, _loc, state) do
    IO.puts("My event: #{inspect(event)}")

    state
  end

  defp get_attribute(attributes, attribute_name, default \\ nil) do
    with {:ok, attribute_value} <- fetch_attribute(attributes, attribute_name) do
      attribute_value
    else
      {:error, {:missing_attribute, _attribute_name}} ->
        default
    end
  end

  defp fetch_attribute(attributes, attribute_name) do
    attribute_value =
      Enum.find_value(attributes, fn
        {_uri, _prefix, ^attribute_name, attribute_value} ->
          attribute_value

        _ ->
          false
      end)

    if attribute_value do
      {:ok, to_string(attribute_value)}
    else
      {:error, {:missing_attribute, attribute_name}}
    end
  end

  defp to_boolean(str) do
    case str do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, :invalid_attribute}
    end
  end

  defp to_date_or_nil(nil) do
    {:ok, nil, 0}
  end

  defp to_date_or_nil(date_string) do
    DateTime.from_iso8601(date_string)
  end

  defp to_ip_or_nil(nil) do
    {:ok, nil}
  end

  defp to_ip_or_nil(ip_string) do
    String.to_charlist(ip_string)
    |> :inet.parse_address()
  end

  defp normalize(chars) do
    chars
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.to_charlist()
  end
end
