defmodule AstarteInstanceIdType do
  use Skogsra.Type

  @impl Skogsra.Type
  def cast(value)

  def cast(value) when is_binary(value) and byte_size(value) <= 41 do
    {:ok, value}
  end

  def cast(_) do
    :error
  end
end
