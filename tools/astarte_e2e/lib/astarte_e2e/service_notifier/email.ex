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

  def service_down_email(reason) do
    from = Config.mail_from_address!()
    to = Config.mail_to_address!()

    text = """
    AstarteE2E detected a service malfunction.

    Reason: #{reason}.
    #{datetime_to_string()}

    Please take actions to prevent further issues.
    """

    new_email()
    |> to(to)
    |> from(from)
    |> subject("Astarte Warning! Service is down")
    |> text_body(text)
  end

  defp datetime_to_string do
    now = DateTime.utc_now()

    day = now.day |> to_padded_string()
    month = now.month |> to_padded_string()
    year = now.year |> to_padded_string()
    hour = now.hour |> to_padded_string()
    minute = now.minute |> to_padded_string()
    second = now.second |> to_padded_string()

    """
    Timezone: #{now.time_zone}
    Date: #{day}/#{month}/#{year}
    Time: #{hour}:#{minute}:#{second}
    """
  end

  defp to_padded_string(num) do
    num
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end
end
