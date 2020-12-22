describe('Interface builder tests', () => {
  context("without an app's config", () => {
    it('starts up as a standalone Interface Editor', () => {
      cy.server();
      cy.route({
        method: 'GET',
        url: '/user-config/config.json',
        status: 404,
        response: '',
      });
      cy.visit('/');
      cy.get('h2').contains('Interface Editor');
      cy.get('#interfaceName').should('have.value', '');

      cy.get('.nav-col .nav').within(() => {
        cy.get('.nav-brand').as('brand').next('.nav-link').as('interfaceEditor');
        cy.get('@brand').should('have.attr', 'href', '/');
        cy.get('@interfaceEditor').should('have.attr', 'href', '/').contains('Interface Editor');
      });
    });
  });

  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/interfaces/new');
      cy.location('pathname').should('eq', '/login');

      cy.visit('/interfaces/testInterface');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();

      cy.fixture('test.astarte.FirstInterface').as('test_interface');
      cy.server();
      cy.route('GET', '/realmmanagement/v1/*/interfaces/*/*', '@test_interface');
      cy.wait(200);
    });

    it('loads empty builder', () => {
      cy.visit('/interfaces/new');
      cy.location('pathname').should('eq', '/interfaces/new');
      cy.get('#interfaceName').should('have.value', '');

      // default interface version should be 0.1
      cy.get('#interfaceMajor').should('have.value', '0');
      cy.get('#interfaceMinor').should('have.value', '1');
    });

    it('shows selected interface', function() {
      const testInterfaceName = this.test_interface.data.interface_name;
      const testInterfaceMajor = this.test_interface.data.version_major;
      const testInterfaceMinor = this.test_interface.data.version_minor;
      cy.visit(`/interfaces/${testInterfaceName}/${testInterfaceMajor}`);
      cy.location('pathname').should('eq', `/interfaces/${testInterfaceName}/${testInterfaceMajor}`);

      cy.get('#interfaceName').should('have.value', testInterfaceName);
      cy.get('#interfaceMajor').should('have.value', testInterfaceMajor).and('have.attr', 'readonly');
      cy.get('#interfaceMinor').should('have.value', testInterfaceMinor);
    });

    it('redirects to list of interfaces after a new interface installation', function () {
      cy.route({
        method: 'POST',
        url: '/realmmanagement/v1/*/interfaces',
        status: 201,
        response: '@test_interface',
      }).as('installInterfaceRequest');
      cy.visit('/interfaces/new');
      cy.get('#interfaceSource')
        .clear()
        .type(JSON.stringify(this.test_interface.data), { parseSpecialCharSequences: false });
      cy.get('button').contains('Install interface').click();
      cy.get('.modal.show button').contains('Confirm').click();
      cy.location('pathname').should('eq', '/interfaces');
      cy.get('h2').contains('Interfaces');
    });
  });
});
