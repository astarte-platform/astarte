defmodule Astarte.RealmManagement.API.Interfaces do
  @moduledoc """
  The boundary for the Interfaces system.
  """

  alias Astarte.RealmManagement.API.Repo
  alias Astarte.RealmManagement.API.Interfaces.RPC.AMQPClient
  alias Astarte.Core.InterfaceDocument, as: Interface

  @doc """
  Returns the list of interfaces.

  ## Examples

      iex> list_interfaces()
      [%Interface{}, ...]

  """
  def list_interfaces(realm_name) do
    AMQPClient.get_interfaces_list(realm_name)
  end

  @doc """
  Gets a single interface.

  Raises if the Interface does not exist.

  ## Examples

      iex> get_interface!(123)
      %Interface{}

  """
  def get_interface!(realm_name, id) do
    for interface_version <- AMQPClient.get_interface_versions_list(realm_name, id) do
      interface_version[:major_version]
    end
  end

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
