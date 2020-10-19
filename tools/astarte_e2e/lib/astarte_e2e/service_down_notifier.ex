#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.ServiceDownNotifier do
  alias AstarteE2EWeb.{Email, Mailer}

  def notify_service_down(reason) do
    reason
    |> Email.service_down_email()
    |> deliver()
  end

  defp deliver(%Bamboo.Email{} = email) do
    with %Bamboo.Email{} = sent_email <- Mailer.deliver_later(email) do
      {:ok, sent_email}
    end
  end
end
