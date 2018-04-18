#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils do
  def pretty_data_trigger_type(data_trigger_type) do
    case data_trigger_type do
      :INCOMING_DATA ->
        :on_incoming_data

      :VALUE_CHANGE ->
        :on_value_change

      :VALUE_CHANGE_APPLIED ->
        :on_value_change_applied

      :PATH_CREATED ->
        :on_path_created

      :PATH_REMOVED ->
        :on_path_removed

      :VALUE_STORED ->
        :on_value_stored
    end
  end

  def pretty_change_type(change_type) do
    case change_type do
      :INCOMING_INTROSPECTION ->
        :on_incoming_introspection

      :INTERFACE_ADDED ->
        :on_interface_added

      :INTERFACE_REMOVED ->
        :on_interface_removed

      :INTERFACE_MINOR_UPDATED ->
        :on_interface_minor_updated
    end
  end

  def pretty_device_event_type(device_event_type) do
    case device_event_type do
      :DEVICE_CONNECTED ->
        :on_device_connection

      :DEVICE_DISCONNECTED ->
        :on_device_disconnection

      :DEVICE_EMPTY_CACHE_RECEIVED ->
        :on_empty_cache_received

      :DEVICE_ERROR ->
        :on_device_error
    end
  end
end
