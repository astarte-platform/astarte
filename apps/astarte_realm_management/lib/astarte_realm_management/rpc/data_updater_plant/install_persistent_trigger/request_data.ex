defmodule Astarte.RealmManagement.RPC.DataUpdaterPlant.InstallPersistentTrigger.RequestData do
  @moduledoc false

  defstruct [
    :object_id,
    :object_type,
    :parent_trigger_id,
    :simple_trigger_id,
    :simple_trigger,
    :trigger_target
  ]

  @type triggerdata() :: %__MODULE__{
          object_id: any(),
          object_type: any(),
          parent_trigger_id: any(),
          simple_trigger_id: any(),
          simple_trigger: any(),
          trigger_target: any()
        }
end
