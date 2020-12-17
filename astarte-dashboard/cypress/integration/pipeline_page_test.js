describe('Pipeline page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/pipelines/pipeline_name');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('pipeline.sample-computation')
        .as('pipeline')
        .then((pipeline) => {
          cy.server();
          cy.route('GET', `/flow/v1/*/pipelines/${pipeline.data.name}`, '@pipeline').as(
            'getPipeline',
          );
          cy.route({
            method: 'DELETE',
            url: `/flow/v1/*/pipelines/${pipeline.data.name}`,
            status: 204,
            response: '',
          }).as('deletePipelineRequest');
          cy.login();
          cy.visit(`/pipelines/${pipeline.data.name}`);
          cy.wait('@getPipeline');
        });
    });

    it('successfully loads Pipeline page', function () {
      cy.location('pathname').should('eq', `/pipelines/${this.pipeline.data.name}`);
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
