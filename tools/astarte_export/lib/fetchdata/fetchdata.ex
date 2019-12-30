defmodule Astarte.Export.FetchData do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.Import
  alias CQEx.Query
  alias CQEx.Result
  require Logger

  defmodule State do
    defstruct [
      :device_id,
      :revision,
      :pending_empty_cache,
      :secret_bcrypt_hash,
      :first_registration,
      :inhibit_request,
      :cert_aki,
      :cert_serial,
      :first_credentials_request,
      :last_credentials_request_ip,
      :total_received_msgs,
      :total_received_bytes,
      :last_connection,
      :last_disconnection,
      :last_seen_ip,
      :interfaces
      ]
   end 

   
   @spec get_connection(String.t()) :: {:ok, identifier()}
 
   def get_connection(realm) do
     {:ok, conn} = Database.connect(realm)
     {:ok, conn}
   end

  
  @spec get_devices(identifier()) :: list()  
   
  def get_devices(conn) do
     statement = "SELECT * from devices;"
     CQEx.Query.call!(conn, statement)
     |> Enum.to_list
  end
  
  
  @spec process_device_data(identifier(), list() ) :: struct()
   
  def process_device_data(conn, device_data) do
    device_id            = device_data[:device_id] |> Device.encode_device_id
    revision             = device_data[:protocol_revision]
    pending_empty_cache  = device_data[:pending_empty_cache] |> to_string |> String.downcase
    secret_bcrypt_hash   = device_data[:credentials_secret]

    first_registration  = device_data[:first_registration]
                          |> DateTime.from_unix!(:microsecond)
                          |> DateTime.to_string

    inhibit_request     = device_data[:inhibit_credentials_request] |> to_string |> String.downcase

    cert_serial         = device_data[:cert_serial]
    cert_aki            = device_data[:cert_aki]

    first_credentials_request
                        = device_data[:first_credentials_request]
                          |> DateTime.from_unix!(:millisecond)
                          |> DateTime.to_string

    last_credentials_request_ip
                        = device_data[:last_credentials_request_ip]
                          |> :inet_parse.ntoa
                          |> Kernel.to_string

    total_received_msgs = device_data[:total_received_msgs]
                          |> Kernel.to_string

    total_received_bytes= device_data[:total_received_bytes]
                          |> Kernel.to_string

    last_connection     = device_data[:last_connection]
                          |> DateTime.from_unix!(:millisecond)
                          |> DateTime.to_string

    last_disconnection  = device_data[:last_disconnection]
                          |> DateTime.from_unix!(:millisecond)
                          |> DateTime.to_string

    last_seen_ip        = device_data[:last_seen_ip]
                          |> :inet_parse.ntoa
                          |> Kernel.to_string
    interface_details =  
    gen_interface_details(conn, device_data)
    
    
    %State{
      device_id: device_id,
      revision:  revision ,
      pending_empty_cache: pending_empty_cache,
      secret_bcrypt_hash: secret_bcrypt_hash,
      first_registration: first_registration,
      inhibit_request:  inhibit_request,
      cert_aki: cert_aki,
      cert_serial: cert_serial,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      last_seen_ip: last_seen_ip,
      interfaces:  interface_details }

    end

  
  defp gen_interface_details(conn, device_data) do
    device_id           = device_data[:device_id]
    introspection       = device_data[:introspection]
    introspection_minor = device_data[:interospection_minor]
    Enum.reduce(introspection, [], 
      fn {interface_name, major_version}, acc ->
        {:ok, interface_description}
           = Interface.fetch_interface_descriptor(conn, interface_name, major_version)
        minor_version  = interface_description.minor_version |> Kernel.to_string
        major_version1 = major_version |> Kernel.to_string
        interface_id   = interface_description.interface_id
        aggregation    = interface_description.aggregation
        storage        = interface_description.storage
        interface_type = interface_description.type
        {:ok, mappings} = Mappings.fetch_interface_mappings(conn, interface_id)
        mapped_data_fields =    
          Enum.reduce(mappings, [], 
            fn mapping, acc1 ->
              endpoint_id = mapping.endpoint_id
              path        = mapping.endpoint
              values =  
                case interface_type do 
                  :datastream ->
                    case aggregation do
                      :individual ->
                        fetch_individual_datastream_values(conn, storage, device_id, interface_id, endpoint_id, path)
                      :object ->
                        fetch_object_datastream_value(conn, storage, device_id, path) 
                    end
                  :properties ->
                    fetch_individual_properties_values(conn, storage, device_id, interface_id)
                end
              case values do 
                [] -> acc1
                _ ->
                   [
                   %{ :path   => path,
                      :type   => {interface_type, aggregation},
                      :value  => values } | acc1 ]
              end
            end)
          [ %{ :interface_name => interface_name,
               :major_version  => major_version1 ,
               :minor_version  => minor_version ,
               :active         => "true",
               :mappings       => mapped_data_fields
             } | acc]
      end)
  end

  defp fetch_individual_datastream_values(conn, storage, device_id,interface_id, endpoint_id, interface_name) do
    statement =
      """
       SELECT double_value, reception_timestamp FROM  #{storage} WHERE device_id=:deviceid AND
       interface_id=:interfaceid AND endpoint_id=:endpointid AND
       path=:interfacename
      """
    interface_query =
      Query.new
      |> Query.statement(statement)
      |> Query.put(:deviceid     , device_id)
      |> Query.put(:interfaceid  , interface_id)
      |> Query.put(:endpointid   , endpoint_id)
      |> Query.put(:interfacename, interface_name)

    {:ok, result} = Query.call(conn, interface_query)
    values = 
      CQEx.Result.all_rows(result)
      |> Enum.map fn list ->
           double_value =
             list[:double_value]
             |> to_charlist

           reception_timestamp =
             list[:reception_timestamp]
             |> DateTime.from_unix!(:millisecond)
             |> DateTime.to_string 
     
           List.keyreplace(list,:double_value, 0, {:double_value, double_value})
           |> List.keyreplace(:reception_timestamp, 0, {:reception_timestamp, reception_timestamp})
         end
    #{:storage_type => {:datastream, :individual}, :values => values }
  end


  defp fetch_object_datastream_value(conn, storage, device_id, interface_name) do
    statement =
      """
        SELECT reception_timestamp, v_realpathdatavalue  from #{storage} where device_id=:deviceid AND path=:interfacename
      """
    interface_query =
      Query.new
      |> Query.statement(statement)
      |> Query.put(:deviceid, device_id)
      |> Query.put(:interfacename,interface_name)

    {:ok, result} = Query.call(conn, interface_query)
    
    values = 
      Result.all_rows(result) 
      |> Enum.map fn list ->
           reception_timestamp =
             list[:reception_timestamp]
             |> DateTime.from_unix!(:millisecond)
             |> DateTime.to_string
                  
           v_realpathdatavalue =
             list[:v_realpathdatavalue]
             |> Kernel.to_string
  
           List.keyreplace(list, :reception_timestamp, 0, {:reception_timestamp, reception_timestamp})
           |> List.keyreplace(:v_realpathdatavalue, 0, {:v_realpathdatavalue, v_realpathdatavalue}) 
      end
    #{:storage_type => {:datastream, :object}, :values => values}
  end

  defp fetch_individual_properties_values(conn, storage, device_id, interface_id) do
    statement =
      """
       SELECT  double_value, reception_timestamp , path from #{storage} where device_id=:deviceid AND interface_id=:interfaceid
      """
    interface_query =
      Query.new
      |> Query.statement(statement)
      |> Query.put(:deviceid, device_id)
      |> Query.put(:interfaceid,interface_id)

    {:ok, result} = Query.call(conn, interface_query)
    values  = 
      Result.all_rows(result)
      |> Enum.map fn list ->
           reception_timestamp =
             list[:reception_timestamp]
             |> DateTime.from_unix!(:millisecond)
             |> DateTime.to_string

           v_realpathdatavalue =
             list[:v_realpathdatavalue]
             |> Kernel.to_string

           List.keyreplace(list, :reception_timestamp, 0, {:reception_timestamp, reception_timestamp})
           |> List.keyreplace(:v_realpathdatavalue, 0, {:v_realpathdatavalue, v_realpathdatavalue})
         end
      #{:storage_type => {properties: :individual}, :values => values}
   end
  end
