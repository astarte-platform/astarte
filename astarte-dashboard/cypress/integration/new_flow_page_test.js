const _ = require('lodash');

describe('New Flow page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/flows/new?pipelineId=test-pipeline');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('flows').as('flows');
      cy.fixture('flow.room1-occupation').as('flow');
      cy.fixture('pipelines').as('pipelines');
      cy.fixture('pipeline.room-occupation')
        .as('pipeline')
        .then((pipeline) => {
          cy.intercept('GET', '/flow/v1/*/flows', { fixture: 'flows' });
          cy.intercept('GET', '/flow/v1/*/flows/*', { fixture: 'flow.room1-occupation' });
          cy.intercept('GET', '/flow/v1/*/pipelines', { fixture: 'pipelines' });
          cy.intercept('GET', '/flow/v1/*/pipelines/*', { fixture: 'pipeline.room-occupation' });
          cy.intercept('POST', '/flow/v1/*/flows', {
            statusCode: 201,
            fixture: 'flow.room1-occupation',
          }).as('postNewFlow');
          cy.login();
          cy.visit(`/flows/new?pipelineId=${pipeline.data.name}`);
        });
    });

    it('successfully loads New Flow page', function () {
      cy.location('pathname').should('eq', '/flows/new');
      cy.location('search').should('eq', `?pipelineId=${this.pipeline.data.name}`);
      cy.get('h2').contains('Flow Configuration');
    });

    it('correctly reports referenced pipeline', function () {
      cy.get('.main-content').contains(this.pipeline.data.name);
    });

    it('can fill out a form to instantiate a new Flow', function () {
      cy.get('.main-content').within(() => {
        cy.get('button').contains('Instantiate Flow').should('be.disabled');
        cy.get('#flowNameInput').clear().paste(this.flow.data.name);
        cy.get('#flowConfigInput').clear().paste(JSON.stringify(this.flow.data.config));
        cy.get('button').contains('Instantiate Flow').click();
        cy.wait('@postNewFlow').its('request.body').should('deep.eq', this.flow);
        cy.location('pathname').should('eq', '/flows');
      });
    });

    it('can instantiate a Flow with the name "new"', function () {
      const newFlow = _.merge({}, this.flow.data, { name: 'new' });
      cy.intercept('POST', '/flow/v1/*/flows', {
        statusCode: 201,
        body: { data: newFlow },
      }).as('postNewFlow');
      cy.get('.main-content').within(() => {
        cy.get('#flowNameInput').clear().paste(newFlow.name);
        cy.get('#flowConfigInput').clear().paste(JSON.stringify(newFlow.config));
        cy.get('button').contains('Instantiate Flow').click();
        cy.wait('@postNewFlow').its('request.body.data').should('deep.eq', newFlow);
        cy.location('pathname').should('eq', '/flows');
      });
    });
  });
});
