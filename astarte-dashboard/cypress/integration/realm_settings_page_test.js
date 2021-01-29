describe('Realm Settings page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/settings');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('config_auth').as('configAuth');
      cy.intercept('GET', '/realmmanagement/v1/*/config/auth', { fixture: 'config_auth' });
      cy.login();
      cy.visit('/settings');
    });

    it('successfully loads Realm Settings page', function () {
      cy.location('pathname').should('eq', '/settings');
      cy.get('h2').contains('Realm Settings');
    });

    it('displays current public key', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Public key')
          .next()
          .should('have.value', this.configAuth.data.jwt_public_key_pem)
          .should('not.be.disabled');
        cy.contains('Change').should('be.disabled');
      });
    });

    it('cannot update current public key with an empty string', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Public key').next().clear();
        cy.contains('Change').should('be.disabled');
      });
    });

    it('can update current public key with a proper value', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Public key')
          .next()
          .clear()
          .paste(this.configAuth.data.jwt_public_key_pem + '\n');
        cy.contains('Change').should('not.be.disabled').click();
      });
      cy.get('[role="dialog"]').contains('Confirm Public Key Update');
      cy.get('[role="dialog"]').contains('Update settings').click();
    });
  });
});
