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
          cy.server();
          cy.route('GET', '/flow/v1/*/flows', '@flows');
          cy.route('GET', '/flow/v1/*/flows/*', '@flow');
          cy.route('GET', '/flow/v1/*/pipelines', '@pipelines');
          cy.route('GET', '/flow/v1/*/pipelines/*', '@pipeline');
          cy.route({
            method: 'POST',
            url: '/flow/v1/*/flows',
            status: 201,
            response: '@flow',
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
        cy.get('#flowNameInput').clear().type(this.flow.data.name);
        cy.get('#flowConfigInput')
          .clear()
          .type(JSON.stringify(this.flow.data.config), { parseSpecialCharSequences: false });
        cy.get('button').contains('Instantiate Flow').click();
        cy.wait('@postNewFlow').its('requestBody').should('deep.eq', this.flow);
        cy.location('pathname').should('eq', '/flows');
      });
    });
  });
});
