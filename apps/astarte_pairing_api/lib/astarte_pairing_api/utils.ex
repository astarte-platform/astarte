defmodule Astarte.Pairing.API.Utils do
  @moduledoc """
  Utility functions for Pairing API.
  """

  @doc """
  Takes a changeset and an error map and adds the errors
  to the changeset.
  """
  def error_map_into_changeset(%Ecto.Changeset{} = changeset, error_map) do
    Enum.reduce(error_map, %{changeset | valid?: false}, fn {k, v}, acc ->
      if v do
        Ecto.Changeset.add_error(acc, k, v)
      else
        acc
      end
    end)
  end
end
