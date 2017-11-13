defmodule Astarte.AppEngine.API.DataTransmitter do
  @moduledoc """
  This module allows Astarte to push data to the devices
  """

  @doc """
  Pushes a payload on a datastream interface.

  ## Options
  `opts` is a keyword list that can contain the following keys:
  * `timestamp`: a timestamp that is added in the BSON object inside the `t` key
  * `metadata`: a map of metadata that is added in the BSON object inside the `m` key
  """
  def push_datastream(realm, device_id, interface, path, payload, opts \\ []) do
    :ok
  end

  @doc """
  Pushes a payload on a properties interface.

  ## Options
  `opts` is a keyword list that can contain the following keys:
  * `timestamp`: a timestamp that is added in the BSON object inside the `t` key
  * `metadata`: a map of metadata that is added in the BSON object inside the `m` key
  """
  def set_property(realm, device_id, interface, path, payload, opts \\ []) do
    :ok
  end

  @doc """
  Pushes an unset message on a properties interface.
  """
  def unset_property(realm, device_id, interface, path) do
    :ok
  end
end
