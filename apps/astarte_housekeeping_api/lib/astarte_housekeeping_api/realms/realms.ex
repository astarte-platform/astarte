defmodule Astarte.Housekeeping.API.Realms do
  @moduledoc """
  The boundary for the Realms system.
  """

  alias Astarte.Housekeeping.API.Realms.RPC.AMQPClient
  alias Astarte.Housekeeping.API.Realms.Realm

  @doc """
  Returns the list of realms.

  ## Examples

      iex> list_realms()
      [%Realm{}, ...]

  """
  def list_realms do
    AMQPClient.list_realms()
  end

  @doc """
  Gets a single realm.

  ## Examples

      iex> get_realm!(123)
      %Realm{}

  """
  def get_realm(realm_name) do
    AMQPClient.get_realm(realm_name)
  end

  @doc """
  Creates a realm.

  ## Examples

      iex> create_realm(%{field: value})
      {:ok, %Realm{}}

      iex> create_realm(%{field: bad_value})
      {:error, ...}

  """
  def create_realm(attrs \\ %{}) do
    changeset = %Realm{}
      |> Realm.changeset(attrs)

    if changeset.valid? do
      realm = Ecto.Changeset.apply_changes(changeset)
      case AMQPClient.create_realm(realm) do
        :ok -> {:ok, realm}

        {:ok, :started} -> {:ok, realm}

        other -> other
      end
    else
      {:error, %{changeset | action: :create}}
    end
  end

  @doc """
  Updates a realm.

  ## Examples

      iex> update_realm(realm, %{field: new_value})
      {:ok, %Realm{}}

      iex> update_realm(realm, %{field: bad_value})
      {:error, ...}

  """
  def update_realm(%Realm{} = realm, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Realm.

  ## Examples

      iex> delete_realm(realm)
      {:ok, %Realm{}}

      iex> delete_realm(realm)
      {:error, ...}

  """
  def delete_realm(%Realm{} = realm) do
    raise "TODO"
  end

  @doc """
  Returns a datastructure for tracking realm changes.

  ## Examples

      iex> change_realm(realm)
      %Todo{...}

  """
  def change_realm(%Realm{} = realm) do
    raise "TODO"
  end
end
