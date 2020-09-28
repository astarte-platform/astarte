describe('Trigger builder tests', () => {
  context('no access before login', () => {
    it('redirects to home', () => {
      cy.visit('/triggers/new');
      cy.location('pathname').should('eq', '/login');
    });

    it('redirects to home', () => {
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
  });
});
