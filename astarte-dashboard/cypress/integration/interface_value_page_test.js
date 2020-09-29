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
      cy.fixture('test.astarte.ParametricObjectInterface').as('interface');
      cy.fixture('test_parametric_object_aggregated_values').as('interface_data');
      cy.fixture('device_detailed').as('device');

      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*/*', '@interface');
      cy.route('GET', '/appengine/v1/*/devices/*', '@device');
      cy.route('GET', '/appengine/v1/*/devices/*/interfaces/*', '@interface_data');
    });

    it('shows correct object aggregated data', function() {
      const deviceId = this.device.data.id;
      const interfaceName = this.interface.data.interface_name;
      cy.visit(`/devices/${deviceId}/interfaces/${interfaceName}`);

      cy.location('pathname').should('eq', `/devices/${deviceId}/interfaces/${interfaceName}`);

      cy.get('h2').contains('Interface Data');
      cy.get('.card-header').contains(interfaceName);
      Object.keys(this.interface_data.data).forEach((sensorId) => {
        cy.get('.card-body p').contains(sensorId);
      });
    });
  });
});
