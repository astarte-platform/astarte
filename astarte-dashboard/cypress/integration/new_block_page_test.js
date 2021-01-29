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
      cy.intercept('POST', '**/flow/v1/**', {
        statusCode: 201,
        fixture: 'custom_block',
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
      cy.wait('@postNewBlock').its('request.body').should('deep.eq', this.customBlock);
      cy.location('pathname').should('eq', '/blocks');
    });

    it('can create a Block with name "new"', function () {
      const newBlock = {
        name: 'new',
        schema: {},
        source: 'source',
        type: 'producer',
      };
      cy.get('.main-content').within(() => {
        cy.get('input#block-name').clear().type(newBlock.name);
        cy.get('select#block-type').select(newBlock.type);
        cy.get('textarea#block-source').clear().type(newBlock.source);
        cy.get('textarea#block-schema').clear().type(JSON.stringify(newBlock.schema));
        cy.contains('Create new block').scrollIntoView().click();
      });
      cy.wait('@postNewBlock').its('request.body.data').should('deep.eq', newBlock);
      cy.location('pathname').should('eq', '/blocks');
    });
  });
});
