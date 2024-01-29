/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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

import _axios from 'axios';

import AstarteClient from './client';

const axios = _axios as unknown as jest.Mock; // Set correct Typescript type
jest.mock('axios');

describe('AstarteClient', () => {
  const realm = 'testrealm';
  const token =
    'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhX2FlYSI6WyIuKjo6LioiXSwiYV9jaCI6WyJKT0lOOjouKiIsIldBVENIOjouKiJdLCJhX3BhIjpbIi4qOjouKiJdLCJhX3JtYSI6WyIuKjo6LioiXSwiaWF0IjoxNjAwNzAxOTQ5fQ.Pj-uHOiIojX2Bn39HbWrhxfXDxLRs2vM1L6JdiGZfcTxUqRQmanM5h3Pbbf3dlVX15GX-S8y-DgfnojgTE1yW8vfXS7P6obFX0JKbNEkaqq0QIgwu2b5dZE3XUA8NjLTkLH63EvHK227okb10kvUn6We3018LInqqGVAGY7kcv-pQDH7MHFz8lFhxj3iCDtxM_5WfqrLhsNXndbQLvwADHoqPzP0kOrvFTGPKwcd8m0JJKrnusFB_lUmgpGLXgAZHAIhhg4wlTCALjLnlvEBcLtxMIs0j-glI8lE1SuCSiWguUwbKnuvoqe3m_Vofq0hUzFZ6_fCy1J__oTw5CkunTQav4xeI9QsyN85xlfwxph9K0yDLK02xbqY5wrV3me9z0RadxsoiNE0lU4mK33hcTfThHyiF3hcxu_A8GBSPwej5gsdetRP16hu2-k_2iVsyiv26MjORb8WAFrJINcf0YD_Yehyqkgv_dN23C8OlmLt90yK8gx05mTVq21rP1Vifrl1RQjuV9BEWjHnpxSDHag7U9UCkjzNmnhg1o7TExBx_owwY1N0kz1B2I7EkmdfUUOFDP80ts4rZwYwTmfiDKriB5DWID-fqpO6IGm_IFKRXoZk_jaovlqdHSpzZqzfescaiVeYrJ_CcVM8HpjASD6UWiI3FHBg0X9cq81lVKw';
  const astarteUrl = 'http://api.example.com';
  const appEngineApiUrl = `${astarteUrl}/appengine/`;
  const pairingApiUrl = `${astarteUrl}/pairing/`;
  const realmManagementApiUrl = `${astarteUrl}/realmmanagement/`;
  const flowApiUrl = `${astarteUrl}/flow/`;
  const astarte = new AstarteClient({
    appEngineApiUrl,
    pairingApiUrl,
    realmManagementApiUrl,
    flowApiUrl,
    realm,
    token,
  });

  it('correctly performs getDeviceData', async () => {
    const deviceId = 'deviceId';
    const interfaceName = 'interfaceName';
    const deviceData = { some: { property: { value: 42 } } };
    axios.mockResolvedValue({ data: { data: deviceData } });

    const fetcheData = await astarte.getDeviceData({ deviceId, interfaceName });
    expect(axios).toHaveBeenCalledTimes(1);
    expect(axios).toHaveBeenCalledWith(
      expect.objectContaining({
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json;charset=UTF-8',
        },
        method: 'get',
      }),
    );
    expect(axios.mock.calls[0][0].url.toString()).toBe(
      `${appEngineApiUrl}v1/${realm}/devices/${deviceId}/interfaces/${interfaceName}?since=&since_after=&to=&limit=`,
    );
    expect(fetcheData).toEqual(deviceData);

    const path = '/some/property';
    const since = '2021-03-20T11:32:34.909Z';
    const sinceAfter = '2021-03-21T11:32:34.909Z';
    const to = '2021-03-22T11:32:34.909Z';
    const limit = 5;
    await astarte.getDeviceData({ deviceId, interfaceName, path, since, sinceAfter, to, limit });
    expect(axios).toHaveBeenCalledTimes(2);
    expect(axios.mock.calls[1][0].url.toString()).toBe(
      `${appEngineApiUrl}v1/${realm}/devices/${deviceId}/interfaces/${interfaceName}${path}?since=${since}&since_after=${sinceAfter}&to=${to}&limit=${limit}`,
    );
  });

  it('correctly performs getDeviceDataTree', async () => {
    const deviceId = 'PO6RuqIXQuysOCAJrcedqA';
    const interfaceName = 'interfaceName';
    const interfaceMajor = 0;
    const interfaceMinor = 1;
    const device = {
      aliases: {},
      connected: false,
      credentials_inhibited: false,
      first_credentials_request: null,
      first_registration: '2020-01-01T12:00:00.000Z',
      groups: [],
      id: deviceId,
      introspection: {
        [interfaceName]: {
          major: interfaceMajor,
          minor: interfaceMinor,
          exchanged_bytes: 0,
          exchanged_msgs: 0,
        },
      },
      last_connection: null,
      last_credentials_request_ip: null,
      last_disconnection: null,
      last_seen_ip: null,
      attributes: {},
      previous_interfaces: [],
      total_received_bytes: 0,
      total_received_msgs: 0,
    };
    const iface = {
      interface_name: interfaceName,
      version_major: interfaceMajor,
      version_minor: interfaceMinor,
      type: 'properties',
      ownership: 'device',
      mappings: [
        {
          endpoint: '/%{room}/heating',
          type: 'boolean',
        },
      ],
    };
    const deviceData = { bedroom: { heating: true } };
    axios.mockImplementationOnce(async () => ({ data: { data: device } })); // Mock first call
    axios.mockImplementationOnce(async () => ({ data: { data: iface } })); // Mock second call
    axios.mockImplementationOnce(async () => ({ data: { data: deviceData } })); // Mock third call

    const fetcheDataTree = await astarte.getDeviceDataTree({ deviceId, interfaceName });
    expect(axios).toHaveBeenCalledTimes(3);
    // First GET to fetch Device
    expect(axios.mock.calls[0][0].url.toString()).toBe(
      `${appEngineApiUrl}v1/${realm}/devices/${deviceId}`,
    );
    // Second GET to fetch Interface
    expect(axios.mock.calls[1][0].url.toString()).toBe(
      `${realmManagementApiUrl}v1/${realm}/interfaces/${interfaceName}/${interfaceMajor}`,
    );
    // Third GET to fetch Device data
    expect(axios.mock.calls[2][0].url.toString()).toBe(
      `${appEngineApiUrl}v1/${realm}/devices/${deviceId}/interfaces/${interfaceName}?since=&since_after=&to=&limit=`,
    );
    expect(fetcheDataTree).toMatchObject({
      endpoint: '',
      dataKind: 'properties',
      children: [
        {
          endpoint: '/bedroom',
          dataKind: 'properties',
          children: [
            {
              endpoint: '/bedroom/heating',
              dataKind: 'properties',
              data: { endpoint: '/bedroom/heating', type: 'boolean', value: true },
            },
          ],
        },
      ],
    });
  });
});
