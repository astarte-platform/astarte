describe('Interface builder tests', () => {
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
  });
});
