const _ = require('lodash');

describe('Flow page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/flows/test-flow/edit');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('flow.room1-occupation')
        .as('flow')
        .then((flow) => {
          cy.intercept('GET', `/flow/v1/*/flows/${flow.data.name}`, flow).as('getFlow');
          cy.login();
          cy.visit(`/flows/${flow.data.name}/edit`);
        });
    });

    it('successfully loads Flow page', function () {
      cy.location('pathname').should('eq', `/flows/${this.flow.data.name}/edit`);
      cy.get('h2').contains('Flow Details');
    });

    it('correctly displays flow details', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Flow configuration');
        cy.get('pre code');
      });
    });

    it('correctly displays a flow with name "new"', function () {
      const flow = _.merge({}, this.flow.data, { name: 'new' });
      cy.intercept('GET', `/flow/v1/*/flows/${flow.name}`, { data: flow }).as('getFlow');
      cy.login();
      cy.visit(`/flows/${flow.name}/edit`);
      cy.location('pathname').should('eq', `/flows/new/edit`);
      cy.get('h2').contains('Flow Details');
      cy.get('.main-content').within(() => {
        cy.contains('Flow configuration');
        cy.get('pre code');
      });
    });
  });
});
