import AstarteClient from '../../src/astarte-client/index.ts';

const interfaceList = [
  {
    interfaceName: 'test.astarte.AggregatedObjectInterface',
    interfaceValuesFixture: 'test_aggregated_object_interface_values',
    interfaceLinearizedValuesFixture: 'test_aggregated_object_interface_linearized_values',
  },
  {
    interfaceName: 'test.astarte.IndividualObjectInterface',
    interfaceValuesFixture: 'test_individual_object_interface_values',
    interfaceLinearizedValuesFixture: 'test_individual_object_interface_linearized_values',
  },
  {
    interfaceName: 'test.astarte.PropertiesInterface',
    interfaceValuesFixture: 'test_properties_interface_values',
    interfaceLinearizedValuesFixture: 'test_properties_interface_linearized_values',
  },
];

describe('Astarte-client tests', () => {
  beforeEach(() => {
    cy.fixture('config/http').then((config) => {
      cy.fixture('realm').then((realm) => {
        cy.wrap(
          new AstarteClient({
            appEngineApiUrl: new URL('appengine/', config.astarte_api_url).toString(),
            pairingApiUrl: new URL('pairing/', config.astarte_api_url).toString(),
            realmManagementApiUrl: new URL('realmmanagement/', config.astarte_api_url).toString(),
            flowApiUrl: new URL('flow/', config.astarte_api_url).toString(),
            realm: realm.name,
            token: realm.infinite_token,
          }),
        ).as('astarteClient');
      });
    });
  });

  context('Devices', () => {
    beforeEach(() => {
      cy.fixture('device_detailed').as('device');
    });

    it("correctly retrieves a device's data and DataTree", function () {
      const deviceId = this.device.data.id;

      // Get device data for different interface types
      interfaceList.forEach(({ interfaceName, interfaceValuesFixture }) => {
        cy.fixture(interfaceValuesFixture).then((interfaceValues) => {
          cy.intercept(
            'GET',
            `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}*`,
            interfaceValues,
          ).as(`getDeviceDataRequest-${interfaceName}`);
          cy.get('@astarteClient')
            .then((astarteClient) => {
              return astarteClient.getDeviceData({
                deviceId,
                interfaceName,
              });
            })
            .as(`deviceData`);
          cy.wait(`@getDeviceDataRequest-${interfaceName}`);
          // Assert expected data from astarte-client
          cy.get(`@deviceData`).should('deep.eq', interfaceValues.data);
        });
      });

      // Get device DataTree for different interface types
      cy.intercept('GET', `/appengine/v1/*/devices/${deviceId}`, this.device);
      interfaceList.forEach(
        ({ interfaceName, interfaceValuesFixture, interfaceLinearizedValuesFixture }) => {
          cy.fixture(interfaceValuesFixture).then((interfaceValues) => {
            cy.intercept(
              'GET',
              `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}*`,
              interfaceValues,
            ).as(`getDeviceDataRequest-${interfaceName}`);
            cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${interfaceName}/*`, {
              fixture: interfaceName,
            });
            cy.get('@astarteClient')
              .then((astarteClient) => {
                return astarteClient.getDeviceDataTree({
                  deviceId,
                  interfaceName,
                });
              })
              .as('deviceDataTree');
            cy.wait(`@getDeviceDataRequest-${interfaceName}`);
            cy.fixture(interfaceLinearizedValuesFixture).then((interfaceLinearizedValues) => {
              cy.get('@deviceDataTree').then((dataTree) => {
                // Assert expected DataTree from astarte-client
                expect(dataTree.toLinearizedData()).to.deep.eq(interfaceLinearizedValues);
              });
            });
          });
        },
      );
    });

    it("correctly retrieves a device's DataTree on a specific interface path", function () {
      const deviceId = this.device.data.id;
      const interfaceName = 'test.astarte.IndividualObjectInterface';
      const interfacePathValuesFixture = 'test_individual_object_interface_path_values';
      const interfacePath = '/sensors/light/estimated';

      // Get device DataTree on a specific interface PATH
      cy.intercept('GET', `/appengine/v1/*/devices/${deviceId}`, this.device);
      cy.fixture(interfacePathValuesFixture).then((interfacePathValues) => {
        cy.intercept(
          'GET',
          `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}${interfacePath}?keep_milliseconds=true&since=&since_after=&to=&limit=`,
          interfacePathValues,
        ).as('getDeviceDataRequest');
        cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${interfaceName}/*`, {
          fixture: interfaceName,
        });
        cy.get('@astarteClient')
          .then((astarteClient) => {
            return astarteClient.getDeviceDataTree({
              deviceId,
              interfaceName,
              path: interfacePath,
            });
          })
          .as('deviceDataTree');
        cy.wait('@getDeviceDataRequest');
        cy.get('@deviceDataTree').then((dataTree) => {
          // Assert expected DataTree from astarte-client
          expect(dataTree.toLinearizedData()).to.deep.eq([
            {
              endpoint: '/sensors/light/estimated',
              timestamp: '2020-10-14T12:27:02.331Z',
              type: 'double',
              value: 81,
            },
            {
              endpoint: '/sensors/light/estimated',
              timestamp: '2020-10-14T12:27:13.200Z',
              type: 'double',
              value: 82,
            },
          ]);
        });

        // Get device DataTree SINCE a specific timestamp
        const since = '2020-10-14T12:27:13.200Z';
        const interfacePathValuesSince = {
          data: interfacePathValues.data.filter((v) => v.timestamp >= since),
        };
        cy.intercept(
          'GET',
          `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}${interfacePath}?*since=${since}*`,
          interfacePathValuesSince,
        ).as('getDeviceDataSinceRequest');
        cy.get('@astarteClient')
          .then((astarteClient) => {
            return astarteClient.getDeviceDataTree({
              deviceId,
              interfaceName,
              path: interfacePath,
              since,
            });
          })
          .as('deviceDataTree');
        cy.wait('@getDeviceDataSinceRequest');
        cy.get('@deviceDataTree').then((dataTree) => {
          // Assert expected DataTree from astarte-client
          expect(dataTree.toLinearizedData()).to.deep.eq([
            {
              endpoint: '/sensors/light/estimated',
              timestamp: '2020-10-14T12:27:13.200Z',
              type: 'double',
              value: 82,
            },
          ]);
        });

        // Get device DataTree TO a specific timestamp
        const to = '2020-10-14T12:27:02.331Z';
        const interfacePathValuesTo = {
          data: interfacePathValues.data.filter((v) => v.timestamp <= to),
        };
        cy.intercept(
          'GET',
          `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}${interfacePath}?*to=${to}*`,
          interfacePathValuesTo,
        ).as('getDeviceDataToRequest');
        cy.get('@astarteClient')
          .then((astarteClient) => {
            return astarteClient.getDeviceDataTree({
              deviceId,
              interfaceName,
              path: interfacePath,
              to,
            });
          })
          .as('deviceDataTree');
        cy.wait('@getDeviceDataToRequest');
        cy.get('@deviceDataTree').then((dataTree) => {
          // Assert expected DataTree from astarte-client
          expect(dataTree.toLinearizedData()).to.deep.eq([
            {
              endpoint: '/sensors/light/estimated',
              timestamp: '2020-10-14T12:27:02.331Z',
              type: 'double',
              value: 81,
            },
          ]);
        });

        // Get device DataTree SINCEAFTER a specific timestamp
        const sinceAfter = '2020-10-14T12:27:13.200Z';
        const interfacePathValuesSinceAfter = {
          data: interfacePathValues.data.filter((v) => v.timestamp > sinceAfter),
        };
        cy.intercept(
          'GET',
          `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}${interfacePath}?*since_after=${sinceAfter}*`,
          interfacePathValuesSinceAfter,
        ).as('getDeviceDataSinceAfterRequest');
        cy.get('@astarteClient')
          .then((astarteClient) => {
            return astarteClient.getDeviceDataTree({
              deviceId,
              interfaceName,
              path: interfacePath,
              sinceAfter,
            });
          })
          .as('deviceDataTree');
        cy.wait('@getDeviceDataSinceAfterRequest');
        cy.get('@deviceDataTree').then((dataTree) => {
          // Assert expected DataTree from astarte-client
          expect(dataTree.toLinearizedData()).to.deep.eq([]);
        });

        // Get device DataTree from last LIMIT values
        const limit = 1;
        const interfacePathValuesLimit = {
          data: interfacePathValues.data.slice(-limit),
        };
        cy.intercept(
          'GET',
          `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}${interfacePath}?*limit=${limit}*`,
          interfacePathValuesLimit,
        ).as('getDeviceDataLimitRequest');
        cy.get('@astarteClient')
          .then((astarteClient) => {
            return astarteClient.getDeviceDataTree({
              deviceId,
              interfaceName,
              path: interfacePath,
              limit,
            });
          })
          .as('deviceDataTree');
        cy.wait('@getDeviceDataLimitRequest');
        cy.get('@deviceDataTree').then((dataTree) => {
          // Assert expected DataTree from astarte-client
          expect(dataTree.toLinearizedData()).to.deep.eq([
            {
              endpoint: '/sensors/light/estimated',
              timestamp: '2020-10-14T12:27:13.200Z',
              type: 'double',
              value: 82,
            },
          ]);
        });
      });
    });
  });
});
