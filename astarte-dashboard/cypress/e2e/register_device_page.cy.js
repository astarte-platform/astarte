import { urlSafeBase64ToByteArray } from '../../src/Base64.ts';

describe('Register device page tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/devices/register');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
      cy.wait(200);
      cy.visit('/devices/register');
    });

    it('successfully loads', () => {
      cy.location('pathname').should('eq', '/devices/register');
      cy.get('h2').contains('Register Device');
    });

    it('random id button generates a valid device id', () => {
      cy.get('.btn').contains('Generate random ID').click();

      cy.get('#deviceIdInput').should(($input) => {
        expect($input).to.have.length(1);

        const byteArray = urlSafeBase64ToByteArray($input[0].value);
        const isValidDeviceId = byteArray.length === 17 && byteArray[16] === 0;

        expect(isValidDeviceId).to.eq(true);
      });
    });

    it('namespaced device id work as expected', () => {
      const namespace = 'a717f8d6-5952-4064-add0-008d780879a9';
      const customString = 'test-string';
      const expectedDeviceId = 'Zb0hSFUSVduexJXxXlGvrA';

      cy.get('.btn').contains('Generate from name').click();

      cy.get('[id$="userNamespace"]').paste(namespace);
      cy.get('[id$="userString"]').paste(customString);

      cy.get('.btn').contains('Generate ID').click();

      cy.get('#deviceIdInput').should(($input) => {
        expect($input).to.have.length(1);
        expect($input[0].value).to.eq(expectedDeviceId);
      });
    });

    // These tests verify that the eval-free validator reproduces the three runtime
    // behaviours previously provided by @rjsf/validator-ajv8:
    //  • transformErrors callbacks rewrite error messages correctly
    //  • failing fields get their specific label highlighted
    //  • errors clear per-field on each keystroke after the first submit

    it('NamespaceModal: pattern violation shows the custom transformErrors message and marks the input invalid', () => {
      cy.get('.btn').contains('Generate from name').click();

      cy.get('.modal').within(() => {
        cy.get('[id$="userNamespace"]').paste('not-a-uuid');
        cy.get('.btn').contains('Generate ID').click();

        // transformErrors rewrote the raw pattern message to this string
        cy.contains('The namespace must be a valid UUID').should('exist');

        // The error must be routed to the input, not a global alert
        cy.get('[id$="userNamespace"]').should('have.class', 'is-invalid');

        cy.get('.modal-header').contains('Generate from name');
      });

      cy.get('#deviceIdInput').should('have.value', '');
    });

    it('NamespaceModal: empty required field shows is-invalid on the input and blocks submission', () => {
      cy.get('.btn').contains('Generate from name').click();

      cy.get('.modal').within(() => {
        cy.get('.btn').contains('Generate ID').click();

        // The error must be routed to the input, not a global alert
        cy.get('[id$="userNamespace"]').should('have.class', 'is-invalid');

        cy.get('.modal-header').contains('Generate from name');
      });

      cy.get('#deviceIdInput').should('have.value', '');
    });

    it('NamespaceModal: typing a valid UUID after a failed submit clears the is-invalid state (liveValidate)', () => {
      cy.get('.btn').contains('Generate from name').click();

      cy.get('.modal').within(() => {
        // First submit sets hasSubmit=true, switching the form to liveValidate
        cy.get('.btn').contains('Generate ID').click();
        cy.get('[id$="userNamespace"]').should('have.class', 'is-invalid');

        // A valid value must clear the error on the next render cycle
        cy.get('[id$="userNamespace"]').paste('753ffc99-dd9d-4a08-a07e-9b0d6ce0bc82');
        cy.get('[id$="userNamespace"]').should('not.have.class', 'is-invalid');
      });
    });

    it('register device to astarte', () => {
      const deviceId = 'Zb0hSFUSVduexJXxXlGvrA';
      const credentialSecret = 'W3Bj5uModtDXSr3lqcjOVuYIRhgdNe1REJKj76v16IM=';
      cy.intercept('POST', '/pairing/v1/*/agent/devices', {
        statusCode: 201,
        body: {
          data: {
            credentials_secret: credentialSecret,
          },
        },
      }).as('registerDeviceCheck');

      cy.get('#deviceIdInput').paste(deviceId);
      cy.get('.btn').contains('Register device').click();

      cy.wait('@registerDeviceCheck')
        .its('request.body')
        .should('deep.equal', {
          data: {
            hw_id: deviceId,
          },
        })
        .then(() => {
          cy.get('.modal-body pre code').contains(credentialSecret).should('be.visible');
        });
    });
  });
});
