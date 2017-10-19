defmodule Astarte.Pairing.API.Agent do
  @moduledoc """
  The Agent context.
  """

  import Ecto.Query, warn: false
  alias Astarte.Pairing.API.Repo

  alias Astarte.Pairing.API.Agent.APIKey

  @doc """
  Returns the list of api_keys.

  ## Examples

      iex> list_api_keys()
      [%APIKey{}, ...]

  """
  def list_api_keys do
    raise "TODO"
  end

  @doc """
  Gets a single api_key.

  Raises if the Api key does not exist.

  ## Examples

      iex> get_api_key!(123)
      %APIKey{}

  """
  def get_api_key!(id), do: raise "TODO"

  @doc """
  Creates a api_key.

  ## Examples

      iex> create_api_key(%{field: value})
      {:ok, %APIKey{}}

      iex> create_api_key(%{field: bad_value})
      {:error, ...}

  """
  def create_api_key(attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a api_key.

  ## Examples

      iex> update_api_key(api_key, %{field: new_value})
      {:ok, %APIKey{}}

      iex> update_api_key(api_key, %{field: bad_value})
      {:error, ...}

  """
  def update_api_key(%APIKey{} = api_key, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a APIKey.

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %APIKey{}}

      iex> delete_api_key(api_key)
      {:error, ...}

  """
  def delete_api_key(%APIKey{} = api_key) do
    raise "TODO"
  end

  @doc """
  Returns a datastructure for tracking api_key changes.

  ## Examples

      iex> change_api_key(api_key)
      %Todo{...}

  """
  def change_api_key(%APIKey{} = api_key) do
    raise "TODO"
  end
end
