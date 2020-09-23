describe('Login tests', () => {
  it('successfully loads', () => {
    cy.visit('/login');
  });

  context('after login pages', () => {
    beforeEach(() => {
      cy.fixture('realm').as('realm');
    });

    it('successfully login', function() {
      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.location('pathname').should('eq', '/');

      cy.get('h2').contains('Astarte Dashboard');
      cy.get('.nav-status').contains(this.realm.name);
    });
  });
});
