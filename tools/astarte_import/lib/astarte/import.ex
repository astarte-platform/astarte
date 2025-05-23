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

defmodule Astarte.Import do
  defmodule State do
    defstruct [
      :device_id,
      :interface,
      :path,
      :reception_timestamp,
      :chars_acc,
      :object_data,
      :current_object_item,
      :value,
      :element_data,
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
      :first_credentials_request,
      :first_registration,
      :last_connection,
      :last_credentials_request_ip,
      :last_disconnection,
      :last_seen_ip,
      :pending_empty_cache,
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

    xmerl_opts = [event_fun: &xml_event/3, continuation_fun: continuation_fun, event_state: state]

    {:ok, state, _tail} = :xmerl_sax_parser.stream(xml, xmerl_opts)

    state.data
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'astarte'}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'devices'}, _attributes}, _loc, state) do
    state
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'device'}, attributes}, _loc, state) do
    {:ok, device_id} = fetch_attribute(attributes, 'device_id')

    %State{state | device_id: device_id}
  end

  # TODO: right now only protocol revision 0 or 1 is supported
  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'protocol'}, attributes}, _loc, state) do
    with {:ok, revision} when revision == "0" or revision == "1" <-
           fetch_attribute(attributes, 'revision'),
         {:ok, pending_empty_cache_string} =
           get_attribute(attributes, 'pending_empty_cache', "false"),
         {:ok, pending_empty_cache} <- to_boolean(pending_empty_cache_string) do
      %State{state | pending_empty_cache: pending_empty_cache}
    else
      {:error, _reason} ->
        throw({:error, :invalid_protocol_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'registration'}, attr}, _loc, state) do
    with {:ok, secret_bcrypt_hash} <- fetch_attribute(attr, 'secret_bcrypt_hash'),
         {:ok, first_registration_string} <- fetch_attribute(attr, 'first_registration'),
         {:ok, first_registration, 0} <- DateTime.from_iso8601(first_registration_string) do
      %State{
        state
        | credentials_secret: secret_bcrypt_hash,
          first_registration: first_registration
      }
    else
      {:error, _reason} ->
        throw({:error, :invalid_registration_element})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'credentials'}, attr}, _loc, state) do
    with {:ok, inhibit_request_string} = get_attribute(attr, 'inhibit_request', "false"),
         {:ok, false} <- to_boolean(inhibit_request_string),
         {:ok, cert_serial} <- get_attribute(attr, 'cert_serial', ""),
         {:ok, cert_aki} <- get_attribute(attr, 'cert_aki', ""),
         {:ok, first_credentials_string} <-
          get_attribute(attr, 'first_credentials_request', nil),
         {:ok, first_credentials_request, 0} <-
            to_date_time(first_credentials_string),
         {:ok, last_creds_ip_string} <-
           get_attribute(attr, 'last_credentials_request_ip', nil),
         {:ok, last_credentials_request_ip} <- to_ip_or_nil(last_creds_ip_string) do
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

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'stats'}, attributes}, _loc, state) do
    with {:ok, total_received_msgs_string} =
           get_attribute(attributes, 'total_received_msgs', "0"),
         {total_received_msgs, ""} <- Integer.parse(total_received_msgs_string),
         {:ok, total_received_bytes_string} =
           get_attribute(attributes, 'total_received_bytes', "0"),
         {total_received_bytes, ""} <- Integer.parse(total_received_bytes_string),
         {:ok, last_connection_string} =
           get_attribute(attributes, 'last_connection', nil),
         {:ok, last_connection, 0} <- to_date_time(last_connection_string),
         {:ok, last_disconnection_string} =
           get_attribute(attributes, 'last_disconnection', nil),
         {:ok, last_disconnection, 0} <- to_date_time(last_disconnection_string),
         {:ok, last_seen_ip_string} = get_attribute(attributes, 'last_seen_ip', nil),
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
         {:startElement, _uri, _l_name, {_prefix, 'interfaces'}, _attributes},
         _loc,
         state
       ) do
    state
  end

  defp xml_event(
         {:startElement, _uri, _l_name, {_prefix, 'interface'}, attributes},
         _loc,
         state
       ) do
    with {:ok, name} <- fetch_attribute(attributes, 'name'),
         {:ok, major_string} <- fetch_attribute(attributes, 'major_version'),
         {major, ""} <- Integer.parse(major_string),
         {:ok, minor_string} <- fetch_attribute(attributes, 'minor_version'),
         {minor, ""} <- Integer.parse(minor_string) do
      %State{
        introspection: introspection,
        old_introspection: old_introspection
      } = state

      {introspection, old_introspection} =
        case get_attribute(attributes, 'active') do
          {:ok, "true"} ->
            unless Map.has_key?(introspection, name) do
              {Map.put(introspection, name, {major, minor}), old_introspection}
            else
              throw({:error, :invalid_interface})
            end

          {:ok, "false"} ->
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
         {:startElement, _uri, _l_name, {_prefix, 'datastream'}, attributes},
         _loc,
         state
       ) do
    {:ok, path} = fetch_attribute(attributes, 'path')

    state = %State{state | path: path}

    case state do
      %State{got_path_fun: nil} ->
        state

      %State{got_path_fun: got_path_fun} ->
        got_path_fun.(state, path)
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'value'}, attributes}, _loc, state) do
    {:ok, reception_timestamp} =
      get_attribute(attributes, 'reception_timestamp', Time.utc_now())

    {:ok, datetime, 0} = DateTime.from_iso8601(reception_timestamp)

    %State{state | reception_timestamp: datetime, element_data: []}
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'object'}, attributes}, _loc, state) do
    {:ok, reception_timestamp} = fetch_attribute(attributes, 'reception_timestamp')

    {:ok, datetime, 0} = DateTime.from_iso8601(reception_timestamp)

    %State{state | reception_timestamp: datetime, object_data: %{}}
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'item'}, attributes}, _loc, state) do
    with {:ok, item_name} <- fetch_attribute(attributes, 'name') do
      %State{state | current_object_item: item_name, element_data: []}
    else
      _any ->
        throw({:error, :invalid_object_item})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'property'}, attributes}, _loc, state) do
    with {:ok, path} <- fetch_attribute(attributes, 'path'),
         {:ok, reception_timestamp} <- fetch_attribute(attributes, 'reception_timestamp'),
         {:ok, datetime, 0} <- DateTime.from_iso8601(reception_timestamp) do
      %State{state | path: path, reception_timestamp: datetime, element_data: []}
    else
      _any ->
        throw({:error, :invalid_property})
    end
  end

  defp xml_event({:startElement, _uri, _l_name, {_prefix, 'element'}, attributes}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'element'}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      element_data: element_data
    } = state

    element_data = element_data ++ [chars_acc]

    %State{state | chars_acc: nil, element_data: element_data}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'property'}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      element_data: element_data,
      got_end_of_property_fun: got_end_of_property_fun
    } = state

    state = got_end_of_property_fun.(state, chars_acc || element_data)

    %State{state | chars_acc: nil, reception_timestamp: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'item'}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      object_data: object_data,
      element_data: element_data,
      current_object_item: current_object_item
    } = state

    object_data = Map.put(object_data, current_object_item, chars_acc || element_data)

    %State{state | chars_acc: nil, object_data: object_data, current_object_item: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'object'}}, _loc, state) do
    %State{
      object_data: object_data,
      got_end_of_object_fun: got_end_of_object_fun
    } = state

    state = got_end_of_object_fun.(state, object_data)

    %State{state | reception_timestamp: nil, object_data: nil, element_data: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'value'}}, _loc, state) do
    %State{
      chars_acc: chars_acc,
      element_data: element_data,
      got_end_of_value_fun: got_end_of_value_fun
    } = state

    state = got_end_of_value_fun.(state, chars_acc || element_data)

    %State{state | chars_acc: nil, reception_timestamp: nil, element_data: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'datastream'}}, _loc, state) do
    state =
      case state do
        %State{got_path_end_fun: nil} ->
          state

        %State{got_path_end_fun: got_path_end_fun} ->
          got_path_end_fun.(state)
      end

    %State{state | path: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'interface'}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'interfaces'}}, _loc, state) do
    %State{state | interface: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'protocol'}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'registration'}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'credentials'}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'stats'}}, _loc, state) do
    state
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'device'}}, _loc, state) do
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

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'devices'}}, _loc, state) do
    %State{state | device_id: nil}
  end

  defp xml_event({:endElement, _uri, _l_name, {_prefix, 'astarte'}}, _loc, state) do
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
    case fetch_attribute(attributes, attribute_name) do
      {:ok, attribute_value} when attribute_value not in ["", nil, []] ->
        {:ok, attribute_value}

      {:error, {:missing_attribute, _attribute_name}} ->
        default

      _ ->
        {:ok, default}
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
      "" -> {:ok, false}
      _ -> {:error, :invalid_attribute}
    end
  end

  defp to_ip_or_nil(nil) do
    {:ok, nil}
  end

  defp to_ip_or_nil(ip_string) do
    String.to_charlist(ip_string)
    |> :inet.parse_address()
  end

  defp to_date_time(date_time_string) do
    case date_time_string do
      nil -> {:ok, nil, 0}
      _-> DateTime.from_iso8601(date_time_string, :extended)
    end
  end
end
