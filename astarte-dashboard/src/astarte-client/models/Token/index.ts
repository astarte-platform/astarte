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

import jwt from 'jsonwebtoken';

import type { AstarteJWT, AstarteDecodedJWT } from '../../types';

type AstarteTokenValidationResult = 'expired' | 'notAnAstarteToken' | 'valid' | 'invalid';

export class AstarteToken {
  private payload: AstarteDecodedJWT | null = null;

  constructor(encodedToken: AstarteJWT) {
    const decodedToken: any = jwt.decode(encodedToken, { complete: true });
    if (decodedToken != null) {
      this.payload = decodedToken.payload as AstarteDecodedJWT;
    }
  }

  get hasAstarteClaims(): boolean {
    if (this.payload == null) {
      return false;
    }
    // AppEngine API
    if ('a_aea' in this.payload) {
      return true;
    }
    // Realm Management API
    if ('a_rma' in this.payload) {
      return true;
    }
    // Pairing API
    if ('a_pa' in this.payload) {
      return true;
    }
    // Astarte Channels
    if ('a_ch' in this.payload) {
      return true;
    }
    return false;
  }

  get isExpired(): boolean {
    if (this.payload == null) {
      return false;
    }
    if (this.payload.exp) {
      const posix = Number.parseInt(this.payload.exp, 10);
      const expiry = new Date(posix * 1000);
      const now = new Date();
      return expiry <= now;
    }
    return false;
  }

  get isValid(): boolean {
    return this.payload != null && !this.isExpired && this.hasAstarteClaims;
  }

  static validate(encodedToken: AstarteJWT): AstarteTokenValidationResult {
    try {
      const token = new AstarteToken(encodedToken);
      if (token.isValid) {
        return 'valid';
      }
      if (token.isExpired) {
        return 'expired';
      }
      if (!token.hasAstarteClaims) {
        return 'notAnAstarteToken';
      }
      return 'invalid';
    } catch {
      return 'invalid';
    }
  }
}
