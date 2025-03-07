#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.AppEngine.API.DateTime do
  @moduledoc """
  Ecto type for DateTimes with millisecond precision.
  """
  use Ecto.Type

  @type t :: DateTime.t()

  @doc false
  def type, do: :utc_datetime_msec

  @spec load(t() | any()) :: {:ok, t()} | :error
  def load(%DateTime{} = datetime), do: {:ok, datetime}
  def load(timestamp) when is_integer(timestamp), do: {:ok, DateTime.from_unix!(timestamp)}
  def load(_other), do: :error

  # xandra accepts both integers and datetimes, it can do the job for us
  @spec dump(t() | any()) :: {:ok, t()} | :error
  def dump(%DateTime{} = datetime), do: {:ok, datetime}
  def dump(timestamp) when is_integer(timestamp), do: {:ok, timestamp}
  def dump(_other), do: :error

  @spec cast(t() | any()) :: {:ok, t()} | :error
  def cast(datetime_or_timestamp_or_any), do: load(datetime_or_timestamp_or_any)
end
