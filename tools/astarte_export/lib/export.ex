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

defmodule Astarte.Export do
  alias Astarte.Export.FetchData
  require Logger
  
  @moduledoc """
  This  module provide API functions to export realm device 
  data in a xml format. This data can be used by astarte_import 
  application utlity  to import into a new realm.
  """
  @doc """
  The export_realm_data/2 function required 2 arguments to export 
  the realm data into XML format.
  the arguments are
   -realm-name -> This is a string format of input
   - path      -> path where to export the realm file.
 
  @spec export_relam_data(String.t, String.t) :: :ok

  """ 
 
  def export_realm_data(realm, path) do
    with true <- File.dir?(path) do
      timestamp = format_time
      filename  = path <> "/" <> realm <> "_" <> timestamp <>  ".xml"
      generate_xml(realm, filename)
    else
      result -> {:error, :invalid_parameters}
    end
  end

  defp generate_xml(realm, file) do
    {:ok, xmlfile} = File.open(file, [:write])
    Logger.info("Export started.", realm: realm)
    xml_data = seralize_xml(realm)
    Logger.info("XML Seralization completed", realm: realm)
    :ok = IO.puts( xmlfile, xml_data)
    Logger.info("Export completed into file: #{file}", realm: realm) 
    :ok = File.close(xmlfile)
  end

  defp seralize_xml(realm) do
    xml_data = 
      seralize_xml(:astrate, [{:realm, realm}])
      |> XmlBuilder.generate 
      |> XmlBuilder.document
      |> XmlBuilder.generate
  end


#######################################################################
# This function will seralize the realm data  to the below format 
# {:tag_name, %{}, ""} 
# which is used by XmlBuilder library to convert to a xml string 
#######################################################################

  @spec seralize_xml(atom(), struct() | keyword()) :: {atom(), map(), String.t() | keyword()}   

  defp seralize_xml(tag, options) do
    {tag, get_attributes(tag, options), get_value(tag, options)} 
  end


######################################################################
#
# get_attributes/2 return a map which hold all attributes to be 
# included in a specific XML tag
#
######################################################################
  
  @spec get_attributes(atom(), struct() | keyword()) :: map()
 
  defp get_attributes(:device, options) do
    state = options[:state]
    %{:device_id => state.device_id }
  end

  defp get_attributes(:protocol, options) do
    state = options[:state]
    %{:revision => state.revision,
      :pending_empty_cache => state.pending_empty_cache
     }
  end


  defp get_attributes(:registration, options) do
    state = options[:state]
    %{ :secret_bcrypt_hash => state.secret_bcrypt_hash,
       :first_registration => state.first_registration
     }
  end

  defp get_attributes(:credentials, options) do
    state = options[:state]
    %{ :inhibit_request   => state.inhibit_request,
       :cert_serial       => state.cert_serial,
       :cert_aki          => state.cert_aki,
       :first_credentials_request => state.first_credentials_request}
  end

  defp get_attributes(:stats, options) do
    state = options[:state]
    %{ :total_received_msgs  => state.total_received_msgs,
       :total_received_bytes => state.total_received_bytes,
       :last_connection      => state.last_connection,
       :last_disconnection   => state.last_disconnection,
       :last_seen_ip         => state.last_seen_ip}
  end

  defp get_attributes(:interfaces, state) do
    %{}
  end

  defp get_attributes(:interface, state) do
    %{ :name          => state.interface_name,
       :major_version => state.major_version,
       :minor_version => state.minor_version,
       :active        => state.active
     }
  end

  defp get_attributes(:datastream, {_type, state}) do
    %{:path => state.path}
  end

  defp get_attributes(:property, state) do
    %{ :path                => state[:path],
       :reception_timestamp => state[:reception_timestamp]
     }
  end

  defp get_attributes(:object, state) do
    %{ :reception_timestamp => state[:reception_timestamp]}
  end

  defp get_attributes(:value, state) do
    %{ :reception_timestamp => state[:reception_timestamp]}
  end

  defp get_attributes(:item, value) do
    %{:name => value[:v_realpathdatavalue]}
  end

  defp get_attributes(_tag, _value) do
    %{}
  end

###############################################################
#
# get_value/2 function is used to construct the Inner XML tag
# (or) data field to be used b/w opening and closing tags
#
###############################################################

  @spec get_value( atom(), struct() | keyword() ) ::  String.t()  
                                                     | charlist() 
                                                     | maybe_improper_list()  

  defp get_value(:astrate, options) do
    [seralize_xml(:devices, options)]
  end

  defp get_value(:devices, [realm: realm]) do
     {:ok, conn} = FetchData.get_connection(realm)
     Logger.info("Connected to database.", realm: realm)
     devices     = FetchData.get_devices(conn)
     Logger.info("Extracted devices information from realm", realm: realm)
     Enum.reduce(devices, [],
       fn device_data, acc ->
          state = FetchData.process_device_data(conn, device_data)
          acc ++ [seralize_xml(:device, [state: state, realm: realm])]
       end)
  end

  defp get_value(:device, options) do
    tag_list = [:protocol,
                :registration,
                :credentials,
                :stats,
                :interfaces]
    Enum.reduce(tag_list, [],
      fn tag, acc ->
        acc ++ [seralize_xml(tag, options)]
      end)
  end


  defp get_value(:interfaces, options) do
    state = options[:state]
    Enum.reduce(state.interfaces , [],
      fn interface_state, acc ->
        acc ++ [seralize_xml(:interface, interface_state)]
      end)
  end

  defp get_value(:interface, interface_state) do
    mappings = interface_state.mappings
    Enum.reduce(mappings, [],
      fn mapping, acc ->
       output =
        case mapping.type do
          {:datastream, _} ->
            seralize_xml(:datastream, mapping)
          {:properties, _ } ->
                Enum.reduce( mapping.value, [],
                  fn value, acc ->
                     acc ++[seralize_xml(:property, value)]
                 end)
        end
        case mapping.type do
           {:datastream, _} ->
               acc  ++ [output]
           {:properties, _} ->
               List.flatten(acc ++ [output]) 
        end
      end)
  end

  defp get_value(:datastream, mapping) do
   Enum.reduce(mapping.value, [],
     fn value, acc ->
       output =
       case mapping.type do 
         {_, :object} ->
            seralize_xml(:object, value)
         {_, :individual} ->
            seralize_xml(:value, value)
       end
       acc ++ [output]
    end)
  end

  defp get_value(:object, value) do
      [seralize_xml(:item, value)]
  end

  defp get_value(:property, value) do
     value[:double_value] |> Kernel.to_string
  end

  defp get_value(:value, value) do
     value[:double_value] |> Kernel.to_string
  end

  defp get_value(tag, _values) do
     "" 
  end


  def format_time() do
      {{year, month, date}, {hour, minute, second}}
       = :calendar.local_time
      to_string(year)  <>
      "_"              <>
      to_string(month) <>
      "_"              <>
      to_string(date)  <>
      "_"              <>
      to_string(hour)  <>
      "_"              <>
      to_string(minute)<>
      "_"              <>
      to_string(second)

   end
end
