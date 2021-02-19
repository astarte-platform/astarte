describe('Home page tests', () => {
  context('no access before login', () => {
    it('redirects to login', function () {
      cy.visit('/');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('devices_stats').as('devicesStats');
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interfaceMajors');
      cy.fixture('triggers').as('triggers');
      cy.intercept('GET', '/appengine/v1/*/stats/devices', { fixture: 'devices_stats' });
      cy.intercept('GET', '/realmmanagement/v1/*/triggers', { fixture: 'triggers' });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces', { fixture: 'interfaces' });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*', { fixture: 'interface_majors' });
      cy.intercept('GET', '/appengine/health', '');
      cy.intercept('GET', '/realmmanagement/health', '');
      cy.intercept('GET', '/pairing/health', '');
      cy.intercept('GET', '/flow/health', '');
      cy.login();
      cy.visit('/');
    });

    it('successfully loads the Home page', () => {
      cy.location('pathname').should('eq', '/');
      cy.get('h2').contains('Astarte Dashboard');
    });

    it('has an API Status card with a table to display services health', () => {
      cy.get('#status-card')
        .contains('API Status')
        .parents('.card')
        .within(() => {
          const services = ['Realm Management', 'AppEngine', 'Pairing', 'Flow'];
          cy.get('table tbody').find('tr').should('have.length', services.length);
          services.forEach((service, index) => {
            cy.get(`table tbody tr:nth-child(${index + 1})`).within(() => {
              cy.contains(service);
              cy.contains('This service is operating normally');
            });
          });
        });
    });

    it('has a Devices card that shows stats on devices', function () {
      cy.get('#devices-card')
        .contains('Devices')
        .parents('.card')
        .within(() => {
          cy.contains('Registered devices').next().contains(this.devicesStats.data.total_devices);
          cy.contains('Connected devices')
            .next()
            .contains(this.devicesStats.data.connected_devices);
        });
    });

    it('has a Interfaces card that shows available interfaces', function () {
      cy.get('#interfaces-card')
        .contains('Interfaces')
        .parents('.card')
        .within(() => {
          this.interfaces.data.slice(0, 4).forEach((interfaceName) => {
            cy.contains(interfaceName);
          });
          if (this.interfaces.data.length > 5) {
            cy.contains(`${this.interfaces.data.length - 4} more installed interfaces`);
          }
          cy.get('button').contains('Install a new interface');
          const interfaceName = this.interfaces.data[0];
          const interfaceMajor = Math.max(this.interfaceMajors.data);
          cy.contains(interfaceName).click();
          cy.location('pathname').should('eq', `/interfaces/${interfaceName}/${interfaceMajor}/edit`);
        });
      cy.visit('/');
      cy.get('#interfaces-card button').contains('Install a new interface').click();
      cy.location('pathname').should('eq', '/interfaces/new');
    });

    it('has a Triggers card that shows available triggers', function () {
      cy.get('#triggers-card')
        .contains('Triggers')
        .parents('.card')
        .within(() => {
          this.triggers.data.slice(0, 4).forEach((trigger) => {
            cy.contains(trigger);
          });
          if (this.triggers.data.length > 5) {
            cy.contains(`${this.triggers.data.length - 4} more installed triggers`);
          }
          cy.get('button').contains('Install a new trigger');
          cy.contains(this.triggers.data[0]).click();
          cy.location('pathname').should('eq', `/triggers/${this.triggers.data[0]}/edit`);
        });
      cy.visit('/');
      cy.get('#triggers-card button').contains('Install a new trigger').click();
      cy.location('pathname').should('eq', '/triggers/new');
    });
  });
});
