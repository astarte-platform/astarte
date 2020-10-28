const blockTypeToLabel = {
  consumer: 'Consumer',
  producer: 'Producer',
  producer_consumer: 'Producer & Consumer',
};

describe('Block page tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/blocks/blockname');
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
            cy.login();
            cy.visit(`/blocks/${customBlock.data.name}`);
          });
      });

      it('successfully loads Block page for a custom block', function () {
        cy.location('pathname').should('eq', `/blocks/${this.customBlock.data.name}`);
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
    });

    context('Block page for a native block', () => {
      beforeEach(() => {
        cy.fixture('native_block')
          .as('nativeBlock')
          .then((nativeBlock) => {
            cy.login();
            cy.visit(`/blocks/${nativeBlock.data.name}`);
            cy.server();
            cy.route('GET', '/flow/v1/*/blocks/*', '@nativeBlock');
          });
      });

      it('successfully loads Block page for a native block', function () {
        cy.location('pathname').should('eq', `/blocks/${this.nativeBlock.data.name}`);
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
    });
  });
});
