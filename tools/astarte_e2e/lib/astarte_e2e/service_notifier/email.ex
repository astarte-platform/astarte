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

defmodule AstarteE2E.ServiceNotifier.Email do
  import Bamboo.Email

  alias AstarteE2E.Config

  def service_down_email(reason, failure_id) do
    text = """
    AstarteE2E detected a service malfunction at #{current_timestamp()}.

    Reason: #{reason}.
    FailureID: #{failure_id}

    Please take actions to prevent further issues.
    """

    base_email()
    |> subject("Astarte Warning! Service is down")
    |> text_body(text)
  end

  def service_up_email(failure_id) do
    text = """
    AstarteE2E service is back to its normal state at #{current_timestamp()}.

    Linked FailureId: #{failure_id}
    """

    base_email()
    |> subject("Astarte: service back to its normal state.")
    |> text_body(text)
  end

  defp base_email do
    from = Config.mail_from_address!()
    to = Config.mail_to_address!()

    new_email()
    |> to(to)
    |> from(from)
  end

  defp current_timestamp do
    DateTime.utc_now() |> DateTime.to_string()
  end
end
