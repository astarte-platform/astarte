defmodule Astarte.Pairing.FDO.Types.ServiceInfo do
  use TypedStruct
  alias Astarte.Pairing.FDO.Types.ServiceInfo

  typedstruct do
    field :key, String.t()
    field :value, term()
  end

  def decode(service_info) do
    with [key, value] <- service_info,
         true <- is_binary(key),
         %CBOR.Tag{tag: :bytes, value: value} <- value,
         {:ok, value, _} <- CBOR.decode(value) do
      service_info =
        %ServiceInfo{
          key: key,
          value: value
        }

      {:ok, service_info}
    else
      _ ->
        # fallback controller: error 100
        {:error, :message_body_error}
    end
  end

  def decode_map(service_info_list) do
    decoded =
      service_info_list
      |> Enum.map(&decode/1)

    Enum.find(decoded, {:ok, decoded}, fn {tag, _} -> tag == :error end)
    |> case do
      {:ok, list} ->
        map =
          Map.new(list, fn {:ok, value} ->
            %ServiceInfo{key: key, value: value} = value
            {key, value}
          end)

        {:ok, map}

      error ->
        error
    end
  end

  def encode(%ServiceInfo{} = service_info) do
    %ServiceInfo{key: key, value: value} = service_info

    encoded_value = CBOR.encode(value)

    [key, COSE.tag_as_byte(encoded_value)]
  end

  def encode_map(service_info_map) do
    service_info_map
    |> Enum.map(fn {key, value} ->
      encode(%ServiceInfo{key: key, value: value})
    end)
  end
end
