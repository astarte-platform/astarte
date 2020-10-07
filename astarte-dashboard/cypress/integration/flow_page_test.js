describe('Flow page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/flows/test-flow');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('flow.room1-occupation')
        .as('flow')
        .then((flow) => {
          cy.server();
          cy.route('GET', `/flow/v1/*/flows/${flow.data.name}`, '@flow').as('getFlow');
          cy.login();
          cy.visit(`/flows/${flow.data.name}`);
        });
    });

    it('successfully loads Flow page', function () {
      cy.location('pathname').should('eq', `/flows/${this.flow.data.name}`);
      cy.get('h2').contains('Flow Details');
    });

    it('correctly displays flow details', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Flow configuration');
        cy.get('pre code');
      });
    });
  });
});
