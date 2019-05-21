{-
   This file is part of Astarte.

   Copyright 2018 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-}


module Types.ExternalMessage exposing (ExternalMsg(..))

import Route exposing (Route)
import Types.FlashMessage exposing (FlashMessageId, Severity)


type ExternalMsg
    = Noop
    | RequestRoute Route
    | RequestRouteWithToken Route String
    | AddFlashMessage Severity String (List String)
    | DismissFlashMessage FlashMessageId
    | Batch (List ExternalMsg)
