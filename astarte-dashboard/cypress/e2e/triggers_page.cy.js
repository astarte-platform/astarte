describe('Triggers page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/triggers');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
      cy.intercept('GET', '/realmmanagement/v1/*/triggers', { fixture: 'triggers' });
      cy.visit('/triggers');
    });

    it('successfully loads', () => {
      cy.location('pathname').should('eq', '/triggers');

      cy.get('h2').contains('Triggers');
      cy.get('.list-group > .list-group-item:nth-child(2) .btn').contains(
        'test.astarte.FirstTrigger',
      );
      cy.get('.list-group > .list-group-item:nth-child(3) .btn').contains(
        'test.astarte.SecondTrigger',
      );
    });

    it('correctly redirects to trigger page when clicking on its name', function () {
      cy.get('.list-group > .list-group-item:nth-child(2) .btn')
        .contains('test.astarte.FirstTrigger')
        .click();
      cy.location('pathname').should('eq', `/triggers/test.astarte.FirstTrigger/edit`);
    });
  });
});
