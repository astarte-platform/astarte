describe('Groups page tests', () => {
  context('no access before login', () => {
    it('redirects to home', function () {
      cy.visit('/groups');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('groups')
        .as('groups')
        .then((groups) => {
          cy.server();
          cy.route('GET', '/appengine/v1/*/groups', '@groups');
          cy.fixture(`group.${groups.data[0]}.devices`).as(`${groups.data[0]}-devices`);
          cy.fixture(`group.${groups.data[1]}.devices`).as(`${groups.data[1]}-devices`);
          cy.route(
            'GET',
            `/appengine/v1/*/groups/${groups.data[0]}/devices?details=true`,
            `@${groups.data[0]}-devices`,
          );
          cy.route(
            'GET',
            `/appengine/v1/*/groups/${groups.data[1]}/devices?details=true`,
            `@${groups.data[1]}-devices`,
          );
          cy.login();
          cy.visit('/groups');
        });
    });

    it('successfully loads Groups page', function () {
      cy.location('pathname').should('eq', '/groups');
      cy.get('h2').contains('Groups');
    });

    it('displays groups list correctly', function () {
      cy.get('.main-content').within(() => {
        cy.get('table tbody').find('tr').should('have.length', this.groups.data.length);
        this.groups.data.forEach((group, index) => {
          cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
            const groupDevices = this[`${group}-devices`].data;
            const connectedGroupDevices = groupDevices.filter((d) => d.connected);
            cy.get('td:nth-child(1)').contains(group);
            cy.get('td:nth-child(2)').contains(connectedGroupDevices.length);
            cy.get('td:nth-child(3)').contains(groupDevices.length);
          });
        });
      });
    });

    it('has a button to create a new group', function () {
      cy.get('.main-content').within(() => {
        cy.get('button').contains('Create new group').click();
        cy.location('pathname').should('eq', '/groups/new');
      });
    });
  });
});
