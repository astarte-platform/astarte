describe('Interface values page tests', () => {
  context('unauthenticated', () => {
    it('redirects to login', () => {
      cy.visit('/devices/test-device-id/interfaces/test.interface.name');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
    });

    it('correctly loads the page', () => {
      cy.visit('/devices/deviceId/interfaces/interfaceName');
      cy.location('pathname').should('eq', '/devices/deviceId/interfaces/interfaceName');
      cy.get('.main-content').within(() => {
        cy.get('h2').contains('Interface Data');
        cy.get('.card-header').contains('deviceId /interfaceName');
      });
    });

    it('pressing back redirects to the device page', () => {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*/*', {
        fixture: 'test.astarte.IndividualObjectInterface',
      });
      cy.intercept('GET', '/appengine/v1/*/devices/*/interfaces/*', {
        fixture: 'test_individual_object_interface_values',
      });

      const deviceId = '0ma4SioESHKk28VhYGcW1w';
      const interfaceName = 'test.astarte.IndividualObjectInterface';

      cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
      cy.get('[aria-label="Back"]').click();
      cy.location('pathname').should('eq', `/devices/${deviceId}/edit`);
    });

    it('correctly handles error while fetching interface', () => {
      cy.fixture('test_aggregated_object_interface_values').as('interface_data');
      cy.fixture('test.astarte.AggregatedObjectInterface')
        .as('interface')
        .then((iface) => {
          cy.fixture('device_detailed')
            .as('device')
            .then((device) => {
              const interfaceName = iface.data.interface_name;
              const deviceId = device.data.id;
              cy.intercept('GET', `/appengine/v1/*/devices/${deviceId}`, device);
              cy.intercept(
                'GET',
                `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}`,
                { fixture: 'test_aggregated_object_interface_values' },
              );
              cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${interfaceName}/*`, {
                statusCode: 418,
                body: '',
              });
              cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
              cy.get('.main-content .card-body').contains("Couldn't load interface data");
            });
        });
    });

    it('correctly handles error while fetching device', () => {
      cy.fixture('test_aggregated_object_interface_values').as('interface_data');
      cy.fixture('test.astarte.AggregatedObjectInterface')
        .as('interface')
        .then((iface) => {
          cy.fixture('device_detailed')
            .as('device')
            .then((device) => {
              const interfaceName = iface.data.interface_name;
              const deviceId = device.data.id;
              cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${interfaceName}/*`, iface);
              cy.intercept(
                'GET',
                `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}`,
                { fixture: 'test_aggregated_object_interface_values' },
              );
              cy.intercept('GET', `/appengine/v1/*/devices/${deviceId}`, {
                statusCode: 418,
                body: '',
              });
              cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
              cy.get('.main-content .card-body').contains("Couldn't load interface data");
            });
        });
    });

    it('correctly handles error while fetching interface data', () => {
      cy.fixture('test_aggregated_object_interface_values').as('interface_data');
      cy.fixture('test.astarte.AggregatedObjectInterface')
        .as('interface')
        .then((iface) => {
          cy.fixture('device_detailed')
            .as('device')
            .then((device) => {
              const interfaceName = iface.data.interface_name;
              const deviceId = device.data.id;
              cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${interfaceName}/*`, iface);
              cy.intercept('GET', `/appengine/v1/*/devices/${deviceId}`, device);
              cy.intercept(
                'GET',
                `/appengine/v1/*/devices/${deviceId}/interfaces/${interfaceName}`,
                {
                  statusCode: 418,
                  body: '',
                },
              );
              cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
              cy.get('.main-content .card-body').contains("Couldn't load interface data");
            });
        });
    });

    context('aggregated datastream interface', () => {
      beforeEach(() => {
        cy.fixture('test.astarte.AggregatedObjectInterface').as('interface');
        cy.fixture('test_aggregated_object_interface_values').as('interface_data');
        cy.fixture('device_detailed').as('device');
        cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*/*', {
          fixture: 'test.astarte.AggregatedObjectInterface',
        });
        cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
        cy.intercept('GET', '/appengine/v1/*/devices/*/interfaces/*', {
          fixture: 'test_aggregated_object_interface_values',
        });
      });

      it('shows correct aggregated datastream data', function () {
        const deviceId = this.device.data.id;
        const interfaceName = this.interface.data.interface_name;
        cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.location('pathname').should('eq', `/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.get('.main-content').within(() => {
          cy.get('.card-header').contains(`${deviceId} /${interfaceName}`);
          Object.keys(this.interface_data.data.sensors).forEach((sensorId) => {
            const sensorData = this.interface_data.data.sensors[sensorId].value;
            cy.get('.card-body p')
              .contains(`/sensors/${sensorId}/value`)
              .next()
              .within(() => {
                cy.get('table tbody tr').should('have.length', sensorData.length);
                cy.get('table thead th').should('have.length', Object.keys(sensorData[0]).length);
                Object.keys(sensorData[0]).forEach((valueLabel) => {
                  cy.get('table thead th').contains(
                    valueLabel === 'timestamp' ? 'Timestamp' : valueLabel,
                  );
                });
              });
          });
        });
      });
    });

    context('individual datastream interface', () => {
      beforeEach(() => {
        cy.fixture('test.astarte.IndividualObjectInterface').as('interface');
        cy.fixture('test_individual_object_interface_values').as('interface_data');
        cy.fixture('device_detailed').as('device');
        cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*/*', {
          fixture: 'test.astarte.IndividualObjectInterface',
        });
        cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
        cy.intercept('GET', '/appengine/v1/*/devices/*/interfaces/*', {
          fixture: 'test_individual_object_interface_values',
        });
      });

      it('shows correct individual datastream data', function () {
        const deviceId = this.device.data.id;
        const interfaceName = this.interface.data.interface_name;
        cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.location('pathname').should('eq', `/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.get('.main-content').within(() => {
          cy.get('.card-header').contains(`${deviceId} /${interfaceName}`);
          cy.get('.card-body table').within(() => {
            cy.get('tbody tr').should('have.length', 5);
            cy.get('thead th').should('have.length', 3);
            cy.get('thead th').contains('Path');
            cy.get('thead th').contains('Last value');
            cy.get('thead th').contains('Last timestamp');
          });
        });
      });
    });

    context('properties interface', () => {
      beforeEach(() => {
        cy.fixture('test.astarte.PropertiesInterface').as('interface');
        cy.fixture('test_properties_interface_values').as('interface_data');
        cy.fixture('device_detailed').as('device');
        cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*/*', {
          fixture: 'test.astarte.PropertiesInterface',
        });
        cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
        cy.intercept('GET', '/appengine/v1/*/devices/*/interfaces/*', {
          fixture: 'test_properties_interface_values',
        });
      });

      it('shows correct properties data', function () {
        const deviceId = this.device.data.id;
        const interfaceName = this.interface.data.interface_name;
        cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.location('pathname').should('eq', `/devices/${deviceId}/interfaces/${interfaceName}`);
        cy.get('.main-content').within(() => {
          cy.get('.card-header').contains(`${deviceId} /${interfaceName}`);
          Object.keys(this.interface_data.data).forEach((key) => {
            cy.get('.card-body pre code').contains(key);
          });
        });
      });
    });
  });
});
