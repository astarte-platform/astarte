describe('Interfaces page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/interfaces');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('require login', () => {
    before(() => {
      cy.login();
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interface_majors');

      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/interfaces', '@interfaces');
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*', '@interface_majors');
    });

    beforeEach(() => {
      cy.visit('/interfaces');
    });

    it('successfully loads', () => {
      cy.location('pathname').should('eq', '/interfaces');

      cy.get('h2').contains('Interfaces');
      cy.get('.list-group > .list-group-item:nth-child(2) .col > a')
        .should('have.attr', 'href').and('contains', 'test.astarte.FirstInterface');
      cy.get('.list-group > .list-group-item:nth-child(3) .col > a')
        .should('have.attr', 'href').and('contains', 'test.astarte.SecondInterface');
      cy.get('.list-group > .list-group-item:nth-child(4) .col > a')
        .should('have.attr', 'href').and('contains', 'test.astarte.ThirdInterface');
    });
  });
});
