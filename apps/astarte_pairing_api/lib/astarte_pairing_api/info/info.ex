defmodule Astarte.Pairing.API.Info do
  @moduledoc """
  The Info context.
  """

  import Ecto.Query, warn: false
  alias Astarte.Pairing.API.Repo

  alias Astarte.Pairing.API.Info.BrokerInfo

  @doc """
  Returns the list of broker_info.

  ## Examples

      iex> list_broker_info()
      [%BrokerInfo{}, ...]

  """
  def list_broker_info do
    raise "TODO"
  end

  @doc """
  Gets a single broker_info.

  Raises if the Broker info does not exist.

  ## Examples

      iex> get_broker_info!(123)
      %BrokerInfo{}

  """
  def get_broker_info!(id), do: raise "TODO"

  @doc """
  Creates a broker_info.

  ## Examples

      iex> create_broker_info(%{field: value})
      {:ok, %BrokerInfo{}}

      iex> create_broker_info(%{field: bad_value})
      {:error, ...}

  """
  def create_broker_info(attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a broker_info.

  ## Examples

      iex> update_broker_info(broker_info, %{field: new_value})
      {:ok, %BrokerInfo{}}

      iex> update_broker_info(broker_info, %{field: bad_value})
      {:error, ...}

  """
  def update_broker_info(%BrokerInfo{} = broker_info, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a BrokerInfo.

  ## Examples

      iex> delete_broker_info(broker_info)
      {:ok, %BrokerInfo{}}

      iex> delete_broker_info(broker_info)
      {:error, ...}

  """
  def delete_broker_info(%BrokerInfo{} = broker_info) do
    raise "TODO"
  end

  @doc """
  Returns a datastructure for tracking broker_info changes.

  ## Examples

      iex> change_broker_info(broker_info)
      %Todo{...}

  """
  def change_broker_info(%BrokerInfo{} = broker_info) do
    raise "TODO"
  end
end
