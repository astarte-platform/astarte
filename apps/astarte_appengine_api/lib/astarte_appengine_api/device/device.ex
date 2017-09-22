defmodule AstarteAppengineApi.Device do
  @moduledoc """
  The Device context.
  """

  import Ecto.Query, warn: false
  alias AstarteAppengineApi.Repo

  alias AstarteAppengineApi.Device.InterfaceValues

  @doc """
  Returns the list of interfaces.

  ## Examples

      iex> list_interfaces()
      [%InterfaceValues{}, ...]

  """
  def list_interfaces do
    raise "TODO"
  end

  @doc """
  Gets a single interface_values.

  Raises if the Interface values does not exist.

  ## Examples

      iex> get_interface_values!(123)
      %InterfaceValues{}

  """
  def get_interface_values!(id), do: raise "TODO"

  @doc """
  Creates a interface_values.

  ## Examples

      iex> create_interface_values(%{field: value})
      {:ok, %InterfaceValues{}}

      iex> create_interface_values(%{field: bad_value})
      {:error, ...}

  """
  def create_interface_values(attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a interface_values.

  ## Examples

      iex> update_interface_values(interface_values, %{field: new_value})
      {:ok, %InterfaceValues{}}

      iex> update_interface_values(interface_values, %{field: bad_value})
      {:error, ...}

  """
  def update_interface_values(%InterfaceValues{} = interface_values, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a InterfaceValues.

  ## Examples

      iex> delete_interface_values(interface_values)
      {:ok, %InterfaceValues{}}

      iex> delete_interface_values(interface_values)
      {:error, ...}

  """
  def delete_interface_values(%InterfaceValues{} = interface_values) do
    raise "TODO"
  end

  @doc """
  Returns a datastructure for tracking interface_values changes.

  ## Examples

      iex> change_interface_values(interface_values)
      %Todo{...}

  """
  def change_interface_values(%InterfaceValues{} = interface_values) do
    raise "TODO"
  end
end
