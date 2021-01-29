describe('Blocks page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/blocks');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(function () {
      cy.fixture('blocks').as('blocks');
      cy.intercept('GET', '/flow/v1/*/blocks', { fixture: 'blocks' });
      cy.login();
      cy.visit('/blocks');
    });

    it('successfully loads Blocks page', () => {
      cy.location('pathname').should('eq', '/blocks');
      cy.get('h2').contains('Blocks');
    });

    it('shows a first card to create a new block', () => {
      cy.get('.main-content').within(() => {
        cy.get('.card')
          .first()
          .within(() => {
            cy.contains('Create your custom block');
            cy.get('button').contains('Create').as('createBlockButton').should('be.visible');
            cy.get('@createBlockButton').click();
            cy.location('pathname').should('eq', '/blocks/new');
          });
      });
    });

    it('displays the list of blocks', function () {
      cy.get('.main-content').within(() => {
        this.blocks.data.forEach((block) => {
          cy.get('.card button').contains(block.name);
        });
      });
    });

    it("native blocks have a Native badge, custom blocks don't", function () {
      cy.get('.main-content').within(() => {
        this.blocks.data.forEach((block) => {
          cy.get('.card button')
            .contains(block.name)
            .parents('.card')
            .within(() => {
              if (block.beam_module) {
                cy.get('.badge').contains('native');
              } else {
                cy.get('.badge').should('not.exist');
              }
            });
        });
      });
    });

    it('each block has a primary button that redirects to the block page', function () {
      cy.get('.main-content .card button.btn-primary').contains('Show').first().click();
      cy.location('pathname').should('eq', `/blocks/${this.blocks.data[0].name}/edit`);
    });
  });
});
