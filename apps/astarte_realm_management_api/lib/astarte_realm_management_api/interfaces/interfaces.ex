defmodule Astarte.RealmManagement.API.Interfaces do
  @moduledoc """
  The boundary for the Interfaces system.
  """

  import Ecto.Query, warn: false
  alias Astarte.RealmManagement.API.Repo

  alias Astarte.RealmManagement.API.Interfaces.Interface

  @doc """
  Returns the list of interfaces.

  ## Examples

      iex> list_interfaces()
      [%Interface{}, ...]

  """
  def list_interfaces do
    raise "TODO"
  end

  @doc """
  Gets a single interface.

  Raises if the Interface does not exist.

  ## Examples

      iex> get_interface!(123)
      %Interface{}

  """
  def get_interface!(id), do: raise "TODO"

  @doc """
  Creates a interface.

  ## Examples

      iex> create_interface(%{field: value})
      {:ok, %Interface{}}

      iex> create_interface(%{field: bad_value})
      {:error, ...}

  """
  def create_interface(attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a interface.

  ## Examples

      iex> update_interface(interface, %{field: new_value})
      {:ok, %Interface{}}

      iex> update_interface(interface, %{field: bad_value})
      {:error, ...}

  """
  def update_interface(%Interface{} = interface, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Interface.

  ## Examples

      iex> delete_interface(interface)
      {:ok, %Interface{}}

      iex> delete_interface(interface)
      {:error, ...}

  """
  def delete_interface(%Interface{} = interface) do
    raise "TODO"
  end

  @doc """
  Returns a datastructure for tracking interface changes.

  ## Examples

      iex> change_interface(interface)
      %Todo{...}

  """
  def change_interface(%Interface{} = interface) do
    raise "TODO"
  end
end
