describe('Group page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/groups/group-name');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('realm').as('realm');
      cy.login();
    });

    it('successfully loads Group page, even when its name has special characters', function () {
      const groupName = 'special characters %20///%%`~!@#$^&*()_-+=[]{};:\'"|\\<>,.';
      const encodedGroupName = encodeURIComponent(groupName);
      const groupFixture = groupName.startsWith('special characters')
        ? `group.special-characters.devices.json`
        : `group.${groupName}.devices.json`;
      cy.fixture(groupFixture).then((groupDevices) => {
        cy.intercept(
          'GET',
          `/appengine/v1/${this.realm.name}/groups/*/devices?details=true`,
          groupDevices,
        );
        cy.visit(`/groups/${encodeURIComponent(encodedGroupName)}/edit`);
        cy.location('pathname').should(
          'eq',
          // Browsers will convert single quotes but encodeURIComponent don't
          `/groups/${encodeURIComponent(encodedGroupName).replace(/'/g, '%27')}/edit`,
        );
        cy.get('h2').contains('Group Devices');
        cy.contains('Devices in group').should('have.text', `Devices in group ${groupName}`);
      });
    });

    it('displays devices list correctly', function () {
      const groupName = 'test-devices';
      const encodedGroupName = encodeURIComponent(groupName);
      const groupFixture = groupName.startsWith('special characters')
        ? `group.special-characters.devices.json`
        : `group.${groupName}.devices.json`;
      cy.fixture(groupFixture).then((groupDevices) => {
        cy.intercept(
          'GET',
          `/appengine/v1/${this.realm.name}/groups/${encodedGroupName}/devices?details=true`,
          groupDevices,
        );
        cy.visit(`/groups/${encodeURIComponent(encodedGroupName)}/edit`);
        cy.get('.main-content').within(() => {
          cy.get('table tbody').find('tr').should('have.length', groupDevices.data.length);
          groupDevices.data.forEach((device, index) => {
            cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
              cy.contains(device.aliases.name || device.id);
              cy.contains(device.last_connection ? 'Connected on' : 'Never connected');
            });
          });
        });
      });
    });

    it('asks confirmation before removing a device from group', function () {
      const groupName = 'test-devices';
      const encodedGroupName = encodeURIComponent(groupName);
      const groupFixture = groupName.startsWith('special characters')
        ? `group.special-characters.devices.json`
        : `group.${groupName}.devices.json`;
      cy.fixture(groupFixture).then((groupDevices) => {
        cy.intercept(
          'GET',
          `/appengine/v1/${this.realm.name}/groups/${encodedGroupName}/devices?details=true`,
          groupDevices,
        );
        cy.visit(`/groups/${encodeURIComponent(encodedGroupName)}/edit`);
        cy.get('.main-content table tbody tr .btn').first().click();
        cy.get('[role="dialog"]').get('button').contains('Remove').click();
      });
    });

    it('correctly removes a device from a group with symbols in its name', function () {
      const groupName = '!"£$%&/()=?^';
      const encodedGroupName = encodeURIComponent(groupName);
      const groupFixture = 'group.special-characters.devices.json';
      cy.fixture(groupFixture).then((groupDevices) => {
        cy.intercept(
          'GET',
          `/appengine/v1/${this.realm.name}/groups/*/devices?details=true`,
          groupDevices,
        );
        cy.intercept('DELETE', `/appengine/v1/${this.realm.name}/groups/*/devices/*`, {
          statusCode: 204,
        }).as('deleteDeviceRequest');

        cy.visit(`/groups/${encodeURIComponent(encodedGroupName)}/edit`);
        cy.get('.main-content table tbody tr .btn').first().click();
        cy.get('[role="dialog"]').get('button').contains('Remove').click();
        cy.wait('@deleteDeviceRequest');
      });
    });
  });
});
