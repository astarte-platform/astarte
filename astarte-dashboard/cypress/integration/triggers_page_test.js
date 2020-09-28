describe('Triggers page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/triggers');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    before(() => {
      cy.login();
      cy.fixture('triggers').as('triggers');

      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/triggers', '@triggers');
    });

    beforeEach(() => {
      cy.visit('/triggers');
    });

    it('successfully loads', () => {
      cy.location('pathname').should('eq', '/triggers');

      cy.get('h2').contains('Triggers');
      cy.get('.list-group > .list-group-item:nth-child(2) .btn')
        .contains('test.astarte.FirstTrigger');
      cy.get('.list-group > .list-group-item:nth-child(3) .btn')
        .contains('test.astarte.SecondTrigger');
    });
  });
});
