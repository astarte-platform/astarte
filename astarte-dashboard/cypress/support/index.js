Cypress.Commands.add('login', () => {
  cy.server();
  cy.route('/user-config/config.json').as('getUserConfig');
  cy.fixture('realm').then((realm) => {
    const session = {
      login_type: 'TokenLogin',
      api_config: {
        secure_connection: true,
        realm_management_url: 'api.example.com/realmmanagement',
        appengine_url: 'api.example.com/appengine',
        pairing_url: 'api.example.com/pairing',
        flow_url: 'api.example.com/flow',
        realm: realm.name,
        token: realm.infinite_token,
        enable_flow_preview: true,
      },
    };
    localStorage.session = JSON.stringify(session);
    cy.visit('/');
    cy.wait('@getUserConfig');
  });
});
