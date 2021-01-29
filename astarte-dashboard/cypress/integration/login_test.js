describe('Login tests', () => {
  it('successfully loads', () => {
    cy.visit('/login');
  });

  context('after login pages', () => {
    beforeEach(() => {
      cy.fixture('realm').as('realm');
      cy.intercept('http://**/appengine/v1/*/stats/devices', { fixture: 'devices_stats' }).as(
        'httpRequest',
      );
      cy.intercept('https://**/appengine/v1/*/stats/devices', { fixture: 'devices_stats' }).as(
        'httpsRequest',
      );
    });

    it('successfully login', function () {
      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.location('pathname').should('eq', '/');

      cy.get('h2').contains('Astarte Dashboard');
      cy.get('.nav-status').contains(this.realm.name);
    });

    it('use unsecure HTTP when configured to do so', function () {
      cy.dynamicIntercept('getUserConfig', 'GET', '/user-config/config.json', {
        fixture: 'config/http',
      });

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.wait('@httpRequest');
    });

    it('use HTTPS when configured to do so', function () {
      cy.dynamicIntercept('getUserConfig', 'GET', '/user-config/config.json', {
        fixture: 'config/https',
      });

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.wait('@httpsRequest');
    });

    it('correctly loads without Flow features when configured to do so', function () {
      cy.dynamicIntercept('getUserConfig', 'GET', '/user-config/config.json', {
        fixture: 'config/flowDisabled',
      });

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.get('#status-card').should('not.contain', 'Flow');
      cy.get('#main-navbar').should('be.visible');
      cy.get('#main-navbar').should('not.contain', 'Flows');
      cy.get('#main-navbar').should('not.contain', 'Pipelines');
      cy.get('#main-navbar').should('not.contain', 'Blocks');
    });

    it('use custom Astarte URLs when configured to do so', function () {
      cy.dynamicIntercept('getUserConfig', 'GET', '/user-config/config.json', {
        fixture: 'config/custom_urls',
      });

      cy.intercept('https://api.example.com/custom-appengine/health', '').as(
        'appEngineHealthRequest',
      );
      cy.intercept('https://api.example.com/custom-realmmanagement/health', '').as(
        'realmManagementHealthRequest',
      );
      cy.intercept('https://api.example.com/custom-pairing/health', '').as('pairingHealthRequest');
      cy.intercept('https://api.example.com/custom-flow/health', '').as('flowHealthRequest');

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.wait([
        '@appEngineHealthRequest',
        '@realmManagementHealthRequest',
        '@pairingHealthRequest',
        '@flowHealthRequest',
      ]);
    });
  });
});
