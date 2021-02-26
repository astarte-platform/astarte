describe('Flows page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/flows');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('flows').as('flows');
      cy.fixture('flow.room1-occupation').as('flow');
      cy.intercept('GET', '/flow/v1/*/flows/*', { fixture: 'flow.room1-occupation' }).as('getFlow');
      cy.intercept('DELETE', `/flow/v1/*/flows/*`, {
        statusCode: 204,
        body: '',
      });
      cy.login();
      cy.visit('/flows');
    });

    it('successfully loads Flows page', () => {
      cy.location('pathname').should('eq', '/flows');
      cy.get('h2').contains('Running Flows');
    });

    it('correctly reports there are no flows running', () => {
      cy.intercept('GET', '/flow/v1/*/flows', { data: [] }).as('getFlows');
      cy.wait(['@getFlows']);
      cy.get('.main-content').within(() => {
        cy.contains('No running flows');
        cy.get('table').should('not.exist');
      });
    });

    it('correctly displays running flows in a table', function () {
      cy.intercept('GET', '/flow/v1/*/flows', this.flows).as('getFlows');
      cy.wait(['@getFlows', '@getFlow']);
      cy.get('.main-content').within(() => {
        cy.get('table tbody').find('tr').should('have.length', this.flows.data.length);
        this.flows.data.forEach((_, index) => {
          cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
            cy.contains(this.flow.data.name);
            cy.contains(this.flow.data.pipeline);
            cy.get('.btn.btn-danger');
          });
        });
      });
    });

    it('each flow name is a link to its dedicated page', function () {
      cy.intercept('GET', '/flow/v1/*/flows', this.flows).as('getFlows');
      cy.wait(['@getFlows', '@getFlow']);
      cy.get('.main-content').within(() => {
        cy.get('table tbody tr:nth-child(1)').contains(this.flow.data.name).click();
        cy.location('pathname').should('eq', `/flows/${this.flow.data.name}/edit`);
      });
    });

    it('shows a confirm dialog when deleting a flow', function () {
      cy.intercept('GET', '/flow/v1/*/flows', this.flows).as('getFlows');
      cy.wait(['@getFlows', '@getFlow']);
      cy.get('.main-content table tbody tr:nth-child(1) .btn.btn-danger').click();
      cy.get('[role="dialog"]').contains(`Delete flow ${this.flow.data.name}?`);
      cy.get('[role="dialog"] button').contains('Remove').click();
      cy.get('[role="dialog"]').should('not.exist');
      cy.location('pathname').should('eq', '/flows');
    });

    it('has a button to instantiate a new flow', () => {
      cy.get('.main-content').within(() => {
        cy.get('button').contains('New flow').click();
        cy.location('pathname').should('eq', '/pipelines');
      });
    });
  });
});
