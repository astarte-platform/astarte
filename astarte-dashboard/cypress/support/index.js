Cypress.Commands.add('login', () => {
  cy.fixture('realm').then((realm) => {
    cy.visit(`/auth?realm=${realm.name}#access_token=${realm.infinite_token}`);
    cy.wait(500);
  });
});
