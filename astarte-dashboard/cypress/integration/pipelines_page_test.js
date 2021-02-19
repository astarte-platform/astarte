describe('Pipelines page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/pipelines');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('pipelines').as('pipelines');
      cy.fixture('pipeline.test-calculation').as('pipeline-test-calculation');
      cy.fixture('pipeline.sample-computation').as('pipeline-sample-computation');
      cy.intercept('GET', '/flow/v1/*/pipelines', { fixture: 'pipelines' }).as('getPipelines');
      cy.intercept('GET', '/flow/v1/*/pipelines/test-calculation', {
        fixture: 'pipeline.test-calculation',
      }).as('get-pipeline-test-calculation');
      cy.intercept('GET', '/flow/v1/*/pipelines/sample-computation', {
        fixture: 'pipeline.sample-computation',
      }).as('get-pipeline-sample-computation');
      cy.login();
      cy.visit('/pipelines');
      cy.wait([
        '@getPipelines',
        '@get-pipeline-test-calculation',
        '@get-pipeline-sample-computation',
      ]);
    });

    it('successfully loads Pipelines page', () => {
      cy.location('pathname').should('eq', '/pipelines');
      cy.get('h2').contains('Pipelines');
    });

    it('has a card to create a new pipeline', () => {
      cy.get('.main-content').within(() => {
        cy.get('.card')
          .first()
          .within(() => {
            cy.contains('New Pipeline');
            cy.contains('Create your custom pipeline');
            cy.get('button').contains('Create').as('createPipelineButton').should('be.visible');
            cy.get('@createPipelineButton').click();
            cy.location('pathname').should('eq', '/pipelines/new');
          });
      });
    });

    it('displays the pipeline list', function () {
      cy.get('.main-content').within(() => {
        this.pipelines.data.forEach((pipelineName) => {
          const pipelineDescription = this[`pipeline-${pipelineName}`].data.description;
          cy.get('.card')
            .contains(pipelineName)
            .parents('.card')
            .within(() => {
              if (pipelineDescription) {
                cy.contains(pipelineDescription);
              }
              cy.get('button').contains('Instantiate').should('not.be.disabled');
            });
        });
      });
    });

    it("can see details of a pipeline by clicking on its card's title", function () {
      cy.get('.main-content').within(() => {
        const pipelineName = this.pipelines.data[0];
        cy.get('.card .card-header').contains(pipelineName).click();
        cy.location('pathname').should('eq', `/pipelines/${pipelineName}/edit`);
      });
    });

    it('can instantiate a pipeline', function () {
      cy.get('.main-content').within(() => {
        const pipelineName = this.pipelines.data[0];
        cy.get('.card')
          .contains(pipelineName)
          .parents('.card')
          .get('button')
          .contains('Instantiate')
          .click();
        cy.location('pathname').should('eq', '/flows/new');
        cy.location('search').should('eq', `?pipelineId=${pipelineName}`);
      });
    });
  });
});
