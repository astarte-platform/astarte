defmodule Astarte.Pairing.FDO.Types.ServiceInfo do
  use TypedStruct
  alias Astarte.Pairing.FDO.Types.ServiceInfo

  typedstruct do
    field :module, String.t()
    field :key, String.t()
    field :value, term()
  end

  def decode(service_info) do
    with [key, value] <- service_info,
         true <- is_binary(key),
         %CBOR.Tag{tag: :bytes, value: cbor_value} <- value,
         {:ok, value, _} <- CBOR.decode(cbor_value),
         [module, key] <- String.split(key, ":", parts: 2) do
      service_info =
        %ServiceInfo{
          module: module,
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
            %ServiceInfo{module: module, key: key, value: value} = value
            {{module, key}, value}
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

  @doc """
  Splits `service_info` into CBOR-encoded chunks, each not exceeding `max_chunk_size` bytes.
  Returns a list of chunks.
  """
  def to_chunks(service_info, max_chunk_size) do
    service_info
    |> ServiceInfo.encode_map()
    |> Enum.chunk_while({[], 0}, chunk_fun(max_chunk_size), after_fun())
  end

  defp chunk_fun(max_chunk_size) do
    fn entry, {current_chunk, current_size} ->
      entry_size = cbor_size(entry)

      if current_size + entry_size > max_chunk_size and current_chunk != [] do
        {:cont, Enum.reverse(current_chunk), {[entry], entry_size}}
      else
        {:cont, {[entry | current_chunk], current_size + entry_size}}
      end
    end
  end

  defp after_fun do
    fn
      {[], _size} -> {:cont, []}
      {current_chunk, _size} -> {:cont, Enum.reverse(current_chunk), []}
    end
  end

  defp cbor_size(term) do
    term |> CBOR.encode() |> byte_size()
  end

  @doc """
  Indicates that the device yielded during Owner Service Info chunk transmission
  by sending an empty ServiceInfo map.
  """
  defguard is_empty(service_info)
           when service_info.module == nil and
                  service_info.key == nil and
                  service_info.value == nil
end
