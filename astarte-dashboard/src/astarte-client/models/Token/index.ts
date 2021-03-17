/* eslint-disable camelcase */
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
import * as yup from 'yup';

interface AstarteTokenObject {
  exp?: number;
  iat?: number;
  iss?: string;
  a_aea?: string[];
  a_ch?: string[];
  a_f?: string[];
  a_hka?: string[];
  a_pa?: string[];
  a_rma?: string[];
}

const channelsClaimRegex = /^(?<action>JOIN|WATCH|\.\*)::(?<resource>.+)$/;
const httpClaimRegex = /^(?<action>DELETE|GET|PATCH|POST|PUT|\.\*)::(?<resource>.+)$/;

type ChannelsAction = 'JOIN' | 'WATCH';
type HTTPAction = 'DELETE' | 'GET' | 'PATCH' | 'POST' | 'PUT';

type Claim = {
  action: RegExp;
  resource: RegExp;
};

type Claims = {
  appEngine: Claim[];
  channels: Claim[];
  flow: Claim[];
  houseKeeping: Claim[];
  pairing: Claim[];
  realmManagement: Claim[];
};

const parseClaim = (claimRegex: RegExp, claim: string): Claim => {
  const {
    // @ts-expect-error incorrect type for RegExp.exec
    groups: { action, resource },
  } = claimRegex.exec(claim);
  return {
    action: new RegExp(action),
    resource: new RegExp(resource),
  };
};

const astarteTokenObjectSchema: yup.ObjectSchema<AstarteTokenObject> = yup
  .object({
    exp: yup.number().integer().min(0).notRequired(),
    iat: yup.number().integer().min(0).notRequired(),
    iss: yup.string().notRequired(),
    a_aea: yup.array(yup.string().required().matches(httpClaimRegex)),
    a_ch: yup.array(yup.string().required().matches(channelsClaimRegex)),
    a_f: yup.array(yup.string().required().matches(httpClaimRegex)),
    a_hka: yup.array(yup.string().required().matches(httpClaimRegex)),
    a_pa: yup.array(yup.string().required().matches(httpClaimRegex)),
    a_rma: yup.array(yup.string().required().matches(httpClaimRegex)),
  })
  .required();

export class AstarteToken {
  private $claims: Claims;

  private $expirationDate: Date | null;

  private $issueDate: Date | null;

  private $issuer: string | null;

  constructor(encodedToken: string) {
    // @ts-expect-error wrong type for decode options
    const decodedToken = jwt.decode(encodedToken, { complete: true, ignoreExpiration: true });
    const tokenObj: AstarteTokenObject = astarteTokenObjectSchema.validateSync(
      decodedToken && decodedToken.payload,
    );
    this.$expirationDate = tokenObj.exp ? new Date(tokenObj.exp * 1000) : null;
    this.$issueDate = tokenObj.iat ? new Date(tokenObj.iat * 1000) : null;
    this.$issuer = tokenObj.iss || null;
    this.$claims = {
      appEngine: (tokenObj.a_aea || []).map((claim) => parseClaim(httpClaimRegex, claim)),
      channels: (tokenObj.a_ch || []).map((claim) => parseClaim(channelsClaimRegex, claim)),
      flow: (tokenObj.a_f || []).map((claim) => parseClaim(httpClaimRegex, claim)),
      houseKeeping: (tokenObj.a_hka || []).map((claim) => parseClaim(httpClaimRegex, claim)),
      pairing: (tokenObj.a_pa || []).map((claim) => parseClaim(httpClaimRegex, claim)),
      realmManagement: (tokenObj.a_rma || []).map((claim) => parseClaim(httpClaimRegex, claim)),
    };
  }

  can(service: keyof Claims, action: ChannelsAction | HTTPAction, resource: string): boolean {
    return this.$claims[service].some(
      (claim) => claim.action.test(action) && claim.resource.test(resource),
    );
  }

  get hasAstarteClaims(): boolean {
    return Object.values(this.$claims).some((serviceClaims) => serviceClaims.length > 0);
  }

  get isExpired(): boolean {
    return this.$expirationDate != null && this.$expirationDate <= new Date();
  }

  get isValid(): boolean {
    return !this.isExpired && this.hasAstarteClaims;
  }

  static validate(encodedToken: string): 'valid' | 'expired' | 'noAstarteClaims' | 'invalid' {
    try {
      const token = new AstarteToken(encodedToken);
      if (token.isValid) {
        return 'valid';
      }
      if (token.isExpired) {
        return 'expired';
      }
      if (!token.hasAstarteClaims) {
        return 'noAstarteClaims';
      }
      return 'invalid';
    } catch {
      return 'invalid';
    }
  }
}
