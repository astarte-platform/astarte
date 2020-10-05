describe('Group page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/groups/test-devices');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('group.test-devices.devices').as('groupDevices');
      cy.server();
      cy.route('GET', '/appengine/v1/*/groups/test-devices/devices?details=true', '@groupDevices');
      cy.login();
      cy.visit('/groups/test-devices');
    });

    it('successfully loads Group page', () => {
      cy.location('pathname').should('eq', '/groups/test-devices');
      cy.get('h2').contains('Group Devices');
    });

    it('displays devices list correctly', function () {
      cy.get('.main-content').within(() => {
        cy.get('table tbody').find('tr').should('have.length', this.groupDevices.data.length);
        this.groupDevices.data.forEach((device, index) => {
          cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
            cy.contains(device.aliases.name || device.id);
            cy.contains(device.last_connection ? 'Connected on' : 'Never connected');
          });
        });
      });
    });

    it('asks confirmation before removing a device from group', () => {
      cy.get('.main-content table tbody tr .btn').first().click();
      cy.get('[role="dialog"]').get('button').contains('Remove').click();
    });
  });
});
