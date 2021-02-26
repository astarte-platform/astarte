describe('Interfaces page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/interfaces');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('require login', () => {
    beforeEach(() => {
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interface_majors');
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces', { fixture: 'interfaces' });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*', { fixture: 'interface_majors' });
      cy.login();
      cy.visit('/interfaces');
    });

    it('successfully loads the Interfaces page', () => {
      cy.location('pathname').should('eq', '/interfaces');
      cy.get('h2').contains('Interfaces');
    });

    it('correctly displays available interfaces', function () {
      const interfaceMajors = this.interface_majors.data;
      this.interfaces.data.sort().forEach((interfaceName, index) => {
        const majorMax = Math.max(...interfaceMajors);
        cy.get('.list-group-item a').contains(interfaceName);
        cy.get(`.list-group > .list-group-item:nth-child(${index + 2})`).within(() => {
          cy.contains(interfaceName).should(
            'have.attr',
            'href',
            `/interfaces/${interfaceName}/${majorMax}/edit`,
          );
          interfaceMajors.forEach((major) => {
            cy.get('a')
              .should('have.attr', 'href', `/interfaces/${interfaceName}/${major}/edit`)
              .get('.badge')
              .contains(`v${major}`);
          });
        });
      });
    });

    it('correctly redirects to interface page when clicking on its name', function () {
      const interfaceMajors = this.interface_majors.data;
      const sampleInterfaceName = this.interfaces.data[0];
      const sampleInterfaceMajor = Math.max(...interfaceMajors);
      cy.get('.list-group-item a').contains(sampleInterfaceName).click();
      cy.location('pathname').should(
        'eq',
        `/interfaces/${sampleInterfaceName}/${sampleInterfaceMajor}/edit`,
      );
    });
  });
});
