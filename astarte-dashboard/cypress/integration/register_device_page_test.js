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
