const _ = require('lodash');

describe('Pipeline page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/pipelines/pipeline_name/edit');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('pipeline.sample-computation')
        .as('pipeline')
        .then((pipeline) => {
          cy.intercept('GET', `/flow/v1/*/pipelines/${pipeline.data.name}`, pipeline).as(
            'getPipeline',
          );
          cy.intercept('DELETE', `/flow/v1/*/pipelines/${pipeline.data.name}`, {
            statusCode: 204,
            body: '',
          }).as('deletePipelineRequest');
          cy.login();
          cy.visit(`/pipelines/${pipeline.data.name}/edit`);
          cy.wait('@getPipeline');
        });
    });

    it('successfully loads Pipeline page', function () {
      cy.location('pathname').should('eq', `/pipelines/${this.pipeline.data.name}/edit`);
      cy.get('h2').contains('Pipeline Details');
    });

    it("correctly displays the pipeline's properties", function () {
      cy.get('.main-content').within(() => {
        cy.contains('Name').next().contains(this.pipeline.data.name);
        if (this.pipeline.data.description) {
          cy.contains('Description').next().contains(this.pipeline.data.description);
        }
        cy.contains('Source');
      });
    });

    it('correctly displays a pipeline with the name "new"', function () {
      const pipeline = _.merge({}, this.pipeline.data, { name: 'new' });
      cy.intercept('GET', `/flow/v1/*/pipelines/${pipeline.name}`, { data: pipeline });
      cy.visit(`/pipelines/${pipeline.name}/edit`);
      cy.location('pathname').should('eq', `/pipelines/new/edit`);
      cy.get('h2').contains('Pipeline Details');
      cy.get('.main-content').contains('Name').next().contains(pipeline.name);
    });

    it('can delete the pipeline', function () {
      cy.get('.main-content').within(() => {
        cy.contains('Delete pipeline').click();
      });
      cy.get('.modal')
        .contains(`Delete pipeline ${this.pipeline.data.name}?`)
        .parents('.modal')
        .as('deleteModal');
      cy.get('@deleteModal').get('button').contains('Remove').click();
      cy.wait('@deletePipelineRequest');
      cy.location('pathname').should('eq', '/pipelines');
    });
  });
});
