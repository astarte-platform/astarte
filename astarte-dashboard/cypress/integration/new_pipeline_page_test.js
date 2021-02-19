const _ = require('lodash');

describe('New Pipeline page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/pipelines/new');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('blocks')
        .as('blocks')
        .then((blocks) => {
          const producerBlocks = blocks.data.filter((b) => b.type === 'producer');
          const producerConsumerBlocks = blocks.data.filter((b) => b.type === 'producer_consumer');
          const consumerBlocks = blocks.data.filter((b) => b.type === 'consumer');
          cy.wrap(producerBlocks).as('producerBlocks');
          cy.wrap(producerConsumerBlocks).as('producerConsumerBlocks');
          cy.wrap(consumerBlocks).as('consumerBlocks');
          cy.fixture('pipeline.sample-computation').as('pipeline');
          cy.intercept('GET', '/flow/v1/*/blocks', blocks);
          cy.intercept('POST', '/flow/v1/*/pipelines', {
            statusCode: 201,
            fixture: 'pipeline.sample-computation',
          }).as('postNewPipeline');
          cy.login();
          cy.visit('/pipelines/new');
        });
    });

    it('successfully loads New Pipeline page', () => {
      cy.location('pathname').should('eq', '/pipelines/new');
      cy.get('h2').contains('New Pipeline');
    });

    it('correctly displays the form with a visual editor', () => {
      cy.get('.main-content').within(() => {
        cy.get('form input#pipeline-name');
        cy.get('form .flow-editor');
        cy.get('button').contains('Generate pipeline source');
        cy.get('button').contains('Create new pipeline').should('not.exist');
      });
    });

    it('correctly displays all blocks in its category in the visual editor', function () {
      cy.get('.main-content .flow-editor').within(() => {
        cy.get('.block-item').should('have.length', this.blocks.data.length + 7);
        this.producerBlocks.forEach((block) => {
          cy.get('.block-label')
            .contains('Producer')
            .nextUntil('.block-label')
            .contains(block.name);
        });
        this.producerConsumerBlocks.forEach((block) => {
          cy.get('.block-label')
            .contains('Producer & Consumer')
            .nextUntil('.block-label')
            .contains(block.name);
        });
        this.consumerBlocks.forEach((block) => {
          cy.get('.block-label').contains('Consumer').nextAll('.block-item').contains(block.name);
        });
      });
    });

    it('notifies when a source cannot be generated from the visual editor, otherwise hide the editor', function () {
      cy.get('.main-content').within(() => {
        const producerBlockName = this.producerBlocks[0].name;
        const consumerBlockName = this.consumerBlocks[0].name;
        cy.get('button').contains('Generate pipeline source').click();
        cy.get('[role="alert"]').contains('Pipelines must start with a producer block');

        cy.get('.flow-editor .block-item')
          .contains(producerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .producer').parents('.node').moveTo(-50, -50);
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();
        cy.get('[role="alert"]').contains('Pipelines must end with a consumer block');

        cy.get('.flow-editor .block-item')
          .contains(consumerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .consumer').parents('.node').moveTo(50, 50);
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();
        cy.get('[role="alert"]').contains('Pipelines must end with a consumer block');

        cy.get('.canvas-container .node .producer .port[data-name="Out"] > div').moveOnto(
          '.canvas-container .node .consumer .port[data-name="In"] > div',
        );
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();
        cy.get('button').contains('Generate pipeline source').should('not.exist');
        cy.get('button').contains('Create new pipeline').should('exist');
        cy.get('.flow-editor').should('not.exist');
      });
    });

    it('shows the visual editor when the Source field is cleared', function () {
      cy.get('.main-content').within(() => {
        const producerBlockName = this.producerBlocks[0].name;
        const consumerBlockName = this.consumerBlocks[0].name;
        cy.get('.flow-editor .block-item')
          .contains(producerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .producer').parents('.node').moveTo(-50, -50);
        cy.get('.flow-editor .block-item')
          .contains(consumerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .consumer').parents('.node').moveTo(50, 50);
        cy.get('.canvas-container .node .producer .port[data-name="Out"] > div').moveOnto(
          '.canvas-container .node .consumer .port[data-name="In"] > div',
        );
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();

        cy.get('#pipeline-source').scrollIntoView().clear();
        cy.get('.flow-editor').should('exist');
        cy.get('button').contains('Create new pipeline').should('not.exist');
        cy.get('button').contains('Generate pipeline source').should('exist');
      });
    });

    it('can create a pipeline without a schema', function () {
      cy.get('.main-content').within(() => {
        const producerBlockName = this.producerBlocks[0].name;
        const consumerBlockName = this.consumerBlocks[0].name;
        cy.get('.flow-editor .block-item')
          .contains(producerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .producer').parents('.node').moveTo(-50, -50);
        cy.get('.flow-editor .block-item')
          .contains(consumerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .consumer').parents('.node').moveTo(50, 50);
        cy.get('.canvas-container .node .producer .port[data-name="Out"] > div').moveOnto(
          '.canvas-container .node .consumer .port[data-name="In"] > div',
        );
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();

        cy.get('#pipeline-name').scrollIntoView().paste(this.pipeline.data.name);
        cy.get('#pipeline-schema').clear();
        cy.get('#pipeline-description').paste(this.pipeline.data.description);
        cy.get('#pipeline-source').type(`{selectall}${this.pipeline.data.source}`);
        cy.get('button').contains('Create new pipeline').scrollIntoView().click();
        cy.wait('@postNewPipeline')
          .its('request.body')
          .should('deep.eq', {
            data: {
              name: this.pipeline.data.name,
              description: this.pipeline.data.description,
              source: this.pipeline.data.source,
            },
          });
        cy.location('pathname').should('eq', '/pipelines');
      });
    });

    it('can create a pipeline with the name "new"', function () {
      const pipeline = _.merge({}, this.pipeline.data, { name: 'new' });
      cy.get('.main-content').within(() => {
        const producerBlockName = this.producerBlocks[0].name;
        const consumerBlockName = this.consumerBlocks[0].name;
        cy.get('.flow-editor .block-item')
          .contains(producerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .producer').parents('.node').moveTo(-50, -50);
        cy.get('.flow-editor .block-item')
          .contains(consumerBlockName)
          .dragOnto('.flow-editor .canvas-container');
        cy.get('.canvas-container .node .consumer').parents('.node').moveTo(50, 50);
        cy.get('.canvas-container .node .producer .port[data-name="Out"] > div').moveOnto(
          '.canvas-container .node .consumer .port[data-name="In"] > div',
        );
        cy.get('button').contains('Generate pipeline source').scrollIntoView().click();

        cy.get('#pipeline-name').scrollIntoView().paste(pipeline.name);
        cy.get('#pipeline-schema').clear();
        cy.get('#pipeline-description').paste(pipeline.description);
        cy.get('#pipeline-source').type(`{selectall}${pipeline.source}`);
        cy.get('button').contains('Create new pipeline').scrollIntoView().click();
        cy.wait('@postNewPipeline')
          .its('request.body')
          .should('deep.eq', {
            data: {
              name: pipeline.name,
              description: pipeline.description,
              source: pipeline.source,
            },
          });
        cy.location('pathname').should('eq', '/pipelines');
      });
    });
  });
});
