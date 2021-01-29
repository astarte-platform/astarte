describe('New Group page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/groups/new');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('devices_detailed').as('devices');
      cy.fixture('group.first-floor.created').as('postNewGroupResponse');
      cy.intercept('GET', '/appengine/v1/*/devices?details=true', { fixture: 'devices_detailed' });
      cy.intercept('POST', '/appengine/v1/*/groups', {
        statusCode: 201,
        fixture: 'group.first-floor.created',
      }).as('postNewGroup');
      cy.login();
      cy.visit('/groups/new');
    });

    it('successfully loads New Group page', () => {
      cy.location('pathname').should('eq', '/groups/new');
      cy.get('h2').contains('Create a New Group');
    });

    it('displays devices list correctly', function () {
      cy.get('.main-content').within(() => {
        cy.get('table tbody').find('tr').should('have.length', this.devices.data.length);
        this.devices.data.forEach((device, index) => {
          cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
            cy.contains(device.id);
            Object.values(device.aliases).forEach((alias) => {
              cy.contains(alias);
            });
          });
        });
      });
    });

    it('correctly filters devices by Device ID or by alias', function () {
      cy.get('.main-content').within(() => {
        const device = this.devices.data.find((d) => Object.values(d.aliases).length > 0);
        const deviceAlias = Object.values(device.aliases)[0];
        cy.get("input[placeholder*='Device ID']").type(device.id);
        cy.get('table tbody').find('tr').should('have.length', 1);
        cy.get("input[placeholder*='Device ID']").clear().type(deviceAlias);
        cy.get('table tbody').find('tr').should('have.length', 1);
      });
    });

    it('reports how many devices are selected, even if they are filtered out', () => {
      cy.get('.main-content').within(() => {
        cy.contains('Please select at least one device');
        cy.get('table tbody tr:nth-child(1) [type="checkbox"]').check();
        cy.contains('1 device selected');
        cy.get('table tbody tr:nth-child(2) [type="checkbox"]').check();
        cy.contains('2 devices selected');
        cy.get("input[placeholder*='Device ID']").type('non-existent-device-id');
        cy.contains('2 devices selected');
      });
    });

    it('cannot create a group without devices', () => {
      cy.get('.main-content').within(() => {
        cy.get('button').contains('Create group').should('be.disabled');
        cy.get('#groupNameInput').type('my_group');
        cy.get('button').contains('Create group').should('be.disabled');
      });
    });

    it('cannot create a group without a name', () => {
      cy.get('.main-content').within(() => {
        cy.get('button').contains('Create group').should('be.disabled');
        cy.get('table tbody tr:nth-child(1) [type="checkbox"]').check();
        cy.get('button').contains('Create group').should('be.disabled');
      });
    });

    it('can create a group with a name and a device', function () {
      cy.get('.main-content').within(() => {
        const groupName = this.postNewGroupResponse.data.group_name;
        const groupDevices = this.devices.data.filter((d) => d.groups.includes(groupName));
        const groupDevicesIds = groupDevices.map((d) => d.id);
        cy.get('button').contains('Create group').should('be.disabled');
        cy.get('#groupNameInput').type(groupName);
        groupDevicesIds.forEach((deviceId) => {
          cy.get("input[placeholder*='Device ID']").clear().type(deviceId);
          cy.get('table tbody tr:nth-child(1) [type="checkbox"]').check();
        });
        cy.get('button').contains('Create group').should('not.be.disabled').click();
        cy.wait('@postNewGroup').its('request.body.data').should('deep.eq', {
          devices: groupDevicesIds,
          group_name: groupName,
        });
        cy.location('pathname').should('eq', '/groups');
      });
    });
  });
});
