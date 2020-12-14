describe('Trigger builder tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/triggers/new');
      cy.location('pathname').should('eq', '/login');
    });

    it('redirects to login', () => {
      cy.visit('/triggers/testTrigger');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interface_majors');
      cy.fixture('test.astarte.FirstInterface').as('interface_source');
      cy.fixture('test.astarte.FirstTrigger').as('test_trigger');

      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/interfaces', '@interfaces');
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*', '@interface_majors');
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*/*', '@interface_source');
      cy.route('GET', '/realmmanagement/v1/*/triggers/*', '@test_trigger');
      cy.wait(200);
    });

    it('loads empty builder', () => {
      cy.visit('/triggers/new');
      cy.location('pathname').should('eq', '/triggers/new');
      cy.get('#triggerName').should('have.value', '');
    });

    it('shows selected trigger', function() {
      cy.visit('/triggers/test.astarte.FirstTrigger');
      cy.location('pathname').should('eq', '/triggers/test.astarte.FirstTrigger');

      cy.get('#triggerName').should('have.value', this.test_trigger.data.name);
      cy.get('#triggerSimpleTriggerType').should('have.value', 'data');
      cy.get('#triggerPath').should('have.value', '/*');
      cy.get('#triggerUrl').should('have.value', 'http://www.example.com');
    });

    it('redirects to list of triggers after a new trigger installation', function () {
      cy.route({
        method: 'POST',
        url: '/realmmanagement/v1/*/triggers',
        status: 201,
        response: '@test_trigger',
      }).as('installTriggerRequest');
      cy.visit('/triggers/new');
      cy.get('#triggerSource')
        .clear()
        .type(JSON.stringify(this.test_trigger.data), { parseSpecialCharSequences: false });
      cy.get('button').contains('Install Trigger').click();
      cy.wait('@installTriggerRequest');
      cy.location('pathname').should('eq', '/triggers');
      cy.get('h2').contains('Triggers');
    });

    it('redirects to list of triggers after deleting a trigger', function () {
      cy.route({
        method: 'DELETE',
        url: `/realmmanagement/v1/*/triggers/${this.test_trigger.data.name}`,
        status: 204,
        response: '',
      }).as('deleteTriggerRequest');
      cy.visit('/triggers/test.astarte.FirstTrigger');
      cy.get('button').contains('Delete trigger').click();
      cy.get('.modal.show #confirmTriggerName').type(this.test_trigger.data.name);
      cy.get('.modal.show button').contains('Confirm').click();
      cy.wait('@deleteTriggerRequest');
      cy.location('pathname').should('eq', '/triggers');
      cy.get('h2').contains('Triggers');
    });
  });
});
