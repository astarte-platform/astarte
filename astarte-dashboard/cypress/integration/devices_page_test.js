describe('Devices page tests', () => {
  context('no access before login', () => {
    it('redirects to login', function () {
      cy.visit('/devices');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('devices_detailed').as('devices');
      cy.fixture('devices_stats').as('devicesStats');
      cy.server();
      cy.route('GET', '/appengine/v1/*/stats/devices', '@devicesStats');
      cy.route('GET', '/appengine/v1/*/devices*details=true*', '@devices');
      cy.login();
      cy.visit('/devices');
    });

    it('successfully loads Devices page', () => {
      cy.location('pathname').should('eq', '/devices');
      cy.get('h2').contains('Devices');
    });

    it('displays devices list correctly', function () {
      cy.get('.main-content').within(() => {
        cy.get('table tbody').find('tr').should('have.length', this.devices.data.length);
        this.devices.data.forEach((device, index) => {
          cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
            cy.contains(device.aliases.name || device.id);
            cy.contains(device.last_connection ? 'Connected on' : 'Never connected');
          });
        });
      });
    });

    it('clicking a Device ID redirects to its page', function () {
      cy.get('.main-content').within(() => {
        const device = this.devices.data[0];
        cy.get('table tbody')
          .contains(device.aliases.name || device.id)
          .click();
        cy.location('pathname').should('eq', `/devices/${device.id}`);
      });
    });

    it('has a button to register a new device', () => {
      cy.get('.main-content').within(() => {
        cy.contains('Register a new device').click();
      });
      cy.location('pathname').should('eq', '/devices/register');
    });
  });
});
