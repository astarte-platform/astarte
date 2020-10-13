/*
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
/* eslint camelcase: 0 */

type TimestampUTC = string;

export interface AstarteDeviceDTO {
  id: string;
  aliases?: {
    [alias: string]: string;
  };
  metadata?: {
    [metadataKey: string]: string;
  };
  introspection?: {
    [interfaceName: string]: {
      major: number;
      minor: number;
      exchanged_msgs?: number;
      exchanged_bytes?: number;
    };
  };
  connected?: boolean;
  last_connection?: TimestampUTC;
  last_disconnection?: TimestampUTC;
  first_registration?: TimestampUTC;
  first_credentials_request?: TimestampUTC;
  last_seen_ip?: string;
  credentials_inhibited?: boolean;
  last_credentials_request_ip?: string;
  total_received_bytes?: number;
  total_received_msgs?: number;
  groups?: string[];
  previous_interfaces?: Array<{
    name: string;
    major: string;
    minor: string;
    exchanged_msgs?: number;
    exchanged_bytes?: number;
  }>;
}
