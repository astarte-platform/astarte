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

defmodule Astarte.PairingWeb.FDOOnboardingController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.DeviceServiceInfoReady
  alias Astarte.Pairing.FDO.ServiceInfo
  alias Astarte.PairingWeb.ApiSpec.Schemas.Fdo
  alias Astarte.PairingWeb.ApiSpec.Schemas.FDOErrors
  alias OpenApiSpex.{MediaType, Response, Schema}

  require Logger

  action_fallback Astarte.PairingWeb.FDOFallbackController

  tags ["fdo"]

  operation :hello_device,
    summary: "FDO TO2 Hello Device",
    operation_id: "FDOHelloDevice",
    description: "Sets up new owner for proof of ownership.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "TO2 Hello Device",
      "application/cbor",
      Fdo.HelloDeviceRequest,
      required: true
    },
    responses: [
      ok: {
        "TO2 ProveOVHdr",
        "application/cbor",
        %Schema{
          type: :array,
          description:
            "ProveOVHdr response is a CBOR array with the following items: [OVHeader, NumOvEntries, HMac, NonceTO2ProveOV, eBSigInfo, xAKeyExchange, helloDeviceHash, maxOwnerMessageSize]",
          items: %Schema{
            type: :string,
            format: :binary
          },
          example: [
            "OVHeader",
            "NumOvEntries",
            "HMac",
            "NonceTO2ProveOV",
            "eBSigInfo",
            "xAKeyExchange",
            "helloDeviceHash",
            "maxOwnerMessageSize"
          ]
        }
      },
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  operation :ov_next_entry,
    security: [%{"FDOSessionToken" => []}],
    summary: "FDO TO2 GetOVNextEntry",
    operation_id: "FDOGetOVNextEntry",
    description: "Requests the next Ownership Voucher Entry.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "TO2 GetOVNextEntry",
      "application/cbor",
      Fdo.GetOVNextEntryRequest,
      required: true
    },
    responses: [
      ok:
        {"TO2 OVNextEntry", "application/cbor",
         %Schema{
           type: :string,
           format: :binary,
           description:
             "Transmits the requested Ownership Voucher entry from the Owner Onboarding Service.",
           example: [
             "OVEntryNum",
             "OVEntry"
           ]
         }},
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.InvalidJWTTokenResponse,
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  operation :prove_device,
    security: [%{"FDOSessionToken" => []}],
    summary: "FDO TO2 ProveDevice",
    operation_id: "FDOProveDevice",
    description: "Proves the provenance of the Device to the new owner.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "TO2 ProveDeviceRequest",
      "application/cbor",
      Fdo.ProveDeviceRequest,
      required: true
    },
    responses: [
      ok:
        {"TO2 Setup Device", "application/cbor",
         %Schema{
           type: :string,
           format: :binary,
           description:
             "This message prepares for ownership transfer, where the credentials previously used to take over the device are
              replaced, based on the new credentials downloaded from the Owner Onboarding Service.",
           example: [
             "RendezvousInfo",
             "Guid",
             "NonceTO2SetupDv",
             "Owner2Key"
           ]
         }},
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.InvalidJWTTokenResponse,
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  operation :done,
    security: [%{"FDOSessionToken" => []}],
    summary: "FDO TO2 Done",
    operation_id: "FDODone",
    description: "Indicates successful completion of the Transfer of Ownership.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "TO2 Done",
      "application/cbor",
      Fdo.DoneRequest,
      required: true
    },
    responses: [
      ok:
        {"TO2 Done2", "application/cbor",
         %Schema{
           type: :string,
           format: :binary,
           description:
             "This message provides an opportunity for a final ACK after the Owner has invoked the System Info block to
                          establish agent-to-server communications between the Device and its final Owner.",
           example: [
             "NonceTO2SetupDv"
           ]
         }},
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.InvalidJWTTokenResponse,
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  operation :service_info_start,
    security: [%{"FDOSessionToken" => []}],
    summary: "FDO TO2 Service Info Ready",
    operation_id: "FDOServiceInfoReady",
    description:
      "This message signals a state change between the authentication phase of the protocol and the provisioning
                  phase (ServiceInfo) negotiation.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "TO2 Service Info Ready",
      "application/cbor",
      Fdo.DeviceServiceInfoStartRequest,
      required: true
    },
    responses: [
      ok:
        {"TO2 OwnerServiceInfoReady", "application/cbor",
         %Schema{
           type: :string,
           format: :binary,
           description:
             "This message responds to TO2.DeviceServiceInfoReady and indicates that the Owner Onboarding Service is
                        ready to start ServiceInfo.",
           example: [
             "maxDeviceServiceInfoSz"
           ]
         }},
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.InvalidJWTTokenResponse,
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  operation :service_info_end,
    security: [%{"FDOSessionToken" => []}],
    summary: "FDO TO2 Service Info",
    operation_id: "FDOServiceInfoEnd",
    description:
      "Sends as many Device to Owner ServiceInfo entries as will conveniently fit into a message, based on protocol
            and Device constraints.",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm the device belongs to.",
        type: :string,
        required: true
      ]
    ],
    request_body: {
      "CBOR Service Info End",
      "application/cbor",
      Fdo.DeviceServiceInfoRequest,
      required: true
    },
    responses: [
      ok:
        {"TO2 OwnerServiceInfo", "application/cbor",
         %Schema{
           type: :string,
           format: :binary,
           description:
             "Sends as many Owner to Device ServiceInfo entries as will conveniently fit into a message, based on protocol
                          and implementation constraints. This message is part of a loop with TO2.DeviceServiceInfo.",
           example: [
             "IsMoreServiceInfo,",
             "IsDone",
             "ServiceInfo"
           ]
         }},
      internal_server_error: %Response{
        description: "FDO error response",
        content: %{
          "application/cbor" => %MediaType{
            schema: %Schema{
              oneOf: [
                FDOErrors.InvalidJWTTokenResponse,
                FDOErrors.ResourceNotFoundResponse,
                FDOErrors.MessageBodyErrorResponse,
                FDOErrors.InvalidMessageErrorResponse,
                FDOErrors.CredReuseErrorResponse,
                FDOErrors.InternalServerErrorResponse
              ]
            }
          }
        }
      }
    ]

  def hello_device(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_hello_device = conn.assigns.cbor_body

    with {:ok, token, response_msg} <-
           OwnerOnboarding.hello_device(realm_name, cbor_hello_device) do
      conn
      |> put_resp_header("authorization", token)
      |> render("default.cbor", %{cbor_response: response_msg})
    end
  end

  def ov_next_entry(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_body = conn.assigns.cbor_body

    guid = conn.assigns.to2_session.guid

    with {:ok, response} <-
           OwnerOnboarding.ov_next_entry(cbor_body, realm_name, guid) do
      conn
      |> render("default.cbor", %{cbor_response: response})
    end
  end

  def prove_device(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    cbor_body = conn.assigns.cbor_body

    with {:ok, session, response} <-
           OwnerOnboarding.prove_device(
             realm_name,
             cbor_body,
             conn.assigns.to2_session
           ) do
      conn
      |> assign(:to2_session, session)
      |> render("secure.cbor", %{response: response})
    end
  end

  def done(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")
    to2_session = conn.assigns.to2_session

    with {:ok, response_msg} <- OwnerOnboarding.done(realm_name, to2_session, conn.assigns.body) do
      conn
      |> render("secure.cbor", %{cbor_response: response_msg})
    end
  end

  def service_info_start(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")

    with {:ok, device_service_info_ready} <- DeviceServiceInfoReady.decode(conn.assigns.body),
         {:ok, session, response} <-
           OwnerOnboarding.build_owner_service_info_ready(
             realm_name,
             conn.assigns.to2_session,
             device_service_info_ready
           ) do
      conn
      |> assign(:to2_session, session)
      |> render("secure.cbor", %{response: response})
    end
  end

  def service_info_end(conn, _params) do
    realm_name = Map.fetch!(conn.params, "realm_name")

    with {:ok, device_service_info} <- DeviceServiceInfo.decode(conn.assigns.body),
         {:ok, response} <-
           ServiceInfo.build_owner_service_info(
             realm_name,
             conn.assigns.to2_session,
             device_service_info
           ) do
      conn
      |> render("secure.cbor", %{cbor_response: response})
    end
  end
end
