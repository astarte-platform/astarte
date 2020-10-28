describe('Interfaces page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/interfaces');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('require login', () => {
    beforeEach(() => {
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interface_majors');
      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/interfaces', '@interfaces');
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*', '@interface_majors');
      cy.login();
      cy.visit('/interfaces');
    });

    it('successfully loads the Interfaces page', () => {
      cy.location('pathname').should('eq', '/interfaces');
      cy.get('h2').contains('Interfaces');
    });

    it('displays links to available interfaces', function () {
      this.interfaces.data.sort().forEach((interfaceName, index) => {
        cy.get(`.list-group > .list-group-item:nth-child(${index + 2}) .col > a`)
          .should('have.attr', 'href')
          .and('contains', interfaceName);
      });
    });
  });
});
