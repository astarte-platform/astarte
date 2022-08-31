#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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
end
