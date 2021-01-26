const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

describe('Block page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/blocks/blockname/edit');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    context('Block page for a custom block', () => {
      beforeEach(() => {
        cy.fixture('custom_block')
          .as('customBlock')
          .then((customBlock) => {
            cy.server();
            cy.route('GET', '/flow/v1/*/blocks/*', '@customBlock');
            cy.route({
              method: 'DELETE',
              url: `/flow/v1/*/blocks/${customBlock.data.name}`,
              status: 204,
              response: '',
            }).as('deleteBlockRequest');
            cy.login();
            cy.visit(`/blocks/${customBlock.data.name}/edit`);
          });
      });

      it('successfully loads Block page for a custom block', function () {
        cy.location('pathname').should('eq', `/blocks/${this.customBlock.data.name}/edit`);
        cy.get('h2').contains('Block Details');
      });

      it('displays correct properties for a custom block', function () {
        cy.get('.main-content').within(() => {
          cy.contains('Name').next().contains(this.customBlock.data.name);
          cy.contains('Type').next().contains(blockTypeToLabel[this.customBlock.data.type]);
          cy.contains('Source');
          cy.contains('Schema');
        });
      });

      it('can delete a custom block', function () {
        cy.get('.main-content').within(() => {
          cy.contains('Delete block').click();
        });
        cy.get('.modal')
          .contains(`Delete block ${this.customBlock.data.name}?`)
          .parents('.modal')
          .as('deleteModal');
        cy.get('@deleteModal').get('button').contains('Remove').click();
        cy.wait('@deleteBlockRequest');
        cy.location('pathname').should('eq', '/blocks');
      });
    });

    context('Block page for a native block', () => {
      beforeEach(() => {
        cy.fixture('native_block')
          .as('nativeBlock')
          .then((nativeBlock) => {
            cy.login();
            cy.visit(`/blocks/${nativeBlock.data.name}/edit`);
            cy.server();
            cy.route('GET', '/flow/v1/*/blocks/*', '@nativeBlock');
          });
      });

      it('successfully loads Block page for a native block', function () {
        cy.location('pathname').should('eq', `/blocks/${this.nativeBlock.data.name}/edit`);
        cy.get('h2').contains('Block Details');
      });

      it('displays correct properties for a native block', function () {
        cy.get('.main-content').within(() => {
          cy.contains('Name').next().contains(this.nativeBlock.data.name);
          cy.contains('Type').next().contains(blockTypeToLabel[this.nativeBlock.data.type]);
          cy.contains('Source').should('not.exist');
          cy.contains('Schema');
        });
      });

      it('cannot delete a native block', function () {
        cy.get('.main-content').within(() => {
          cy.contains('Delete block').should('not.exist');
        });
      });
    });
  });
});
