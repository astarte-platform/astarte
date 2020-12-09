describe('Login tests', () => {
  it('successfully loads', () => {
    cy.visit('/login');
  });

  context('after login pages', () => {
    beforeEach(() => {
      cy.fixture('realm').as('realm');
      cy.fixture('devices_stats').as('devicesStats');
      cy.server();
      cy.route('http://**/appengine/v1/*/stats/devices', '@devicesStats').as('httpRequest');
      cy.route('https://**/appengine/v1/*/stats/devices', '@devicesStats').as('httpsRequest');
    });

    it('successfully login', function() {
      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.location('pathname').should('eq', '/');

      cy.get('h2').contains('Astarte Dashboard');
      cy.get('.nav-status').contains(this.realm.name);
    });

    it('use unsecure HTTP when configured to do so', function() {
      cy.fixture('config/http').then((userConfig) => {
        cy.route('/user-config/config.json', userConfig);
      });

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.wait('@httpRequest');
    });

    it('use HTTPS when configured to do so', function() {
      cy.fixture('config/https').then((userConfig) => {
        cy.route('/user-config/config.json', userConfig);
      });

      cy.visit('/login');

      cy.get('input[id=astarteRealm]').clear().type(this.realm.name);
      cy.get('textarea[id=astarteToken]').type(this.realm.infinite_token);
      cy.get('.btn[type=submit]').click();

      cy.wait('@httpsRequest');
    });

    it('correctly loads without Flow features when configured to do so', function () {
      cy.fixture('config/flowDisabled').then((userConfig) => {
        cy.route('/user-config/config.json', userConfig);
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
      cy.fixture('config/custom_urls').then((userConfig) => {
        cy.route('/user-config/config.json', userConfig);
        cy.route('https://api.example.com/custom-appengine/health', '').as(
          'appEngineHealthRequest',
        );
        cy.route('https://api.example.com/custom-realmmanagement/health', '').as(
          'realmManagementHealthRequest',
        );
        cy.route('https://api.example.com/custom-pairing/health', '').as('pairingHealthRequest');
        cy.route('https://api.example.com/custom-flow/health', '').as('flowHealthRequest');

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
});
