describe('New block page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/blocks/new');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('custom_block').as('customBlock');
      cy.server();
      cy.route({
        method: 'POST',
        url: '**/flow/v1/**',
        status: 201,
        response: '@customBlock',
      }).as('postNewBlock');
      cy.login();
      cy.visit('/blocks/new');
    });

    it('successfully loads New Block page', () => {
      cy.location('pathname').should('eq', '/blocks/new');
      cy.get('h2').contains('New Block');
    });

    it('can fill out a form for a new Block', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Create new block').should('be.disabled');
        cy.get('input#block-name').clear().type('customblock');
        cy.get('select#block-type').select('producer');
        cy.get('textarea#block-source').clear().type('source');
        cy.get('textarea#block-schema').clear().type('{}');
        cy.contains('Create new block').should('not.be.disabled');
        cy.contains('Create new block').click({ force: true });
      });
      cy.wait('@postNewBlock').its('requestBody').should('deep.eq', this.customBlock);
      cy.location('pathname').should('eq', '/blocks');
    });
  });
});
