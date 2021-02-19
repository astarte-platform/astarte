const _ = require('lodash');

const parseMappingOptions = (mapping) => {
  return {
    reliability: _.get(mapping, 'reliability', 'unreliable'),
    explicitTimestamp: _.get(mapping, 'explicit_timestamp', false),
    retention: _.get(mapping, 'retention', 'discard'),
    expiry: _.get(mapping, 'expiry', 0),
    databaseRetention: _.get(mapping, 'database_retention_policy', 'no_ttl'),
    databaseTTL: _.get(mapping, 'database_retention_ttl'),
    allowUnset: _.get(mapping, 'allow_unset', false),
  };
};

const setupInterfaceEditorFromSource = (iface) => {
  cy.get('#interfaceSource').clear().paste(JSON.stringify(iface));
  cy.wait(500);
};

const setupInterfaceEditorFromUI = (iface) => {
  cy.get('#interfaceName').scrollIntoView().clear().paste(iface.interface_name);
  if (iface.version_major > 0) {
    cy.get('#interfaceMajor').scrollIntoView().type(`{selectall}${iface.version_major}`);
    cy.get('#interfaceMinor').scrollIntoView().type(`{selectall}${iface.version_minor}`);
  } else {
    cy.get('#interfaceMinor').scrollIntoView().type(`{selectall}${iface.version_minor}`);
    cy.get('#interfaceMajor').scrollIntoView().type(`{selectall}${iface.version_major}`);
  }
  if (iface.ownership === 'server') {
    cy.get('#interfaceOwnershipServer').scrollIntoView().check();
  } else {
    cy.get('#interfaceOwnershipDevice').scrollIntoView().check();
  }
  if (iface.type === 'properties') {
    cy.get('#interfaceTypeProperties').scrollIntoView().scrollIntoView().check();
  } else {
    cy.get('#interfaceTypeDatastream').scrollIntoView().check();
    if (iface.aggregation === 'object') {
      cy.get('#interfaceAggregationObject').scrollIntoView().check();
    } else {
      cy.get('#interfaceAggregationIndividual').scrollIntoView().check();
    }
  }
  if (iface.aggregation === 'object') {
    const {
      reliability,
      explicitTimestamp,
      retention,
      expiry,
      databaseRetention,
      databaseTTL,
    } = parseMappingOptions(_.get(iface.mappings, '0'));
    cy.get('#objectMappingReliability').scrollIntoView().select(reliability);
    if (explicitTimestamp) {
      cy.get('#objectMappingExplicitTimestamp').scrollIntoView().check();
    } else {
      cy.get('#objectMappingExplicitTimestamp').scrollIntoView().uncheck();
    }
    cy.get('#objectMappingRetention').scrollIntoView().select(retention);
    cy.get('#objectMappingDatabaseRetention').scrollIntoView().select(databaseRetention);
    if (retention !== 'discard') {
      cy.get('#objectMappingExpiry').scrollIntoView().type(`{selectall}${expiry}`);
    }
    if (databaseRetention !== 'no_ttl') {
      cy.get('#objectMappingTTL').scrollIntoView().type(`{selectall}${databaseTTL}`);
    }
  }
  cy.get('#interfaceDescription').scrollIntoView().clear();
  if (iface.description) {
    cy.get('#interfaceDescription').scrollIntoView().paste(iface.description);
  }
  cy.get('#interfaceDocumentation').scrollIntoView().clear();
  if (iface.doc) {
    cy.get('#interfaceDocumentation').scrollIntoView().paste(iface.doc);
  }
  (iface.mappings || []).forEach((mapping) => {
    cy.get('button').contains('Add new mapping...').click();
    cy.get('.modal.show').within(() => {
      cy.get('#mappingEndpoint').scrollIntoView().clear().paste(mapping.endpoint);
      cy.get('#mappingType').scrollIntoView().select(mapping.type);
      cy.get('#mappingDescription').scrollIntoView().clear();
      if (mapping.description) {
        cy.get('#mappingDescription').scrollIntoView().paste(mapping.description);
      }
      cy.get('#mappingDocumentation').scrollIntoView().clear();
      if (mapping.doc) {
        cy.get('#mappingDocumentation').scrollIntoView().paste(mapping.doc);
      }
      const {
        reliability,
        explicitTimestamp,
        retention,
        expiry,
        databaseRetention,
        databaseTTL,
        allowUnset,
      } = parseMappingOptions(mapping);
      if (iface.type === 'properties') {
        if (allowUnset) {
          cy.get('#mappingAllowUnset').scrollIntoView().check();
        } else {
          cy.get('#mappingAllowUnset').scrollIntoView().uncheck();
        }
      } else if (iface.type === 'datastream' && iface.aggregation !== 'object') {
        cy.get('#mappingReliability').scrollIntoView().select(reliability);
        cy.get('#mappingRetention').scrollIntoView().select(retention);
        cy.get('#mappingDatabaseRetention').scrollIntoView().select(databaseRetention);
        if (explicitTimestamp) {
          cy.get('#mappingExplicitTimestamp').scrollIntoView().check();
        } else {
          cy.get('#mappingExplicitTimestamp').scrollIntoView().uncheck();
        }
        if (retention !== 'discard') {
          cy.get('#mappingExpiry').scrollIntoView().type(`{selectall}${expiry}`);
        }
        if (databaseRetention !== 'no_ttl') {
          cy.get('#mappingTTL').scrollIntoView().type(`{selectall}${databaseTTL}`);
        }
      }
      cy.get('button').contains('Confirm').click();
    });
  });
};

const checkMappingEditorUIValues = ({ mapping, type, aggregation = 'individual' }) => {
  cy.get(`[data-testid="${mapping.endpoint}"]`)
    .scrollIntoView()
    .should('be.visible')
    .within(() => {
      cy.contains(mapping.endpoint);
      cy.get('button').contains('Edit...').click();
    });
  cy.get('.modal.show').within(() => {
    cy.get('#mappingEndpoint')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', mapping.endpoint);
    cy.get('#mappingType').scrollIntoView().should('be.visible').and('have.value', mapping.type);
    cy.get('#mappingDescription')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', mapping.description || '');
    cy.get('#mappingDocumentation')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', mapping.doc || '');
    const {
      reliability,
      explicitTimestamp,
      retention,
      expiry,
      databaseRetention,
      databaseTTL,
      allowUnset,
    } = parseMappingOptions(mapping);
    if (type === 'properties') {
      cy.get('#mappingAllowUnset')
        .scrollIntoView()
        .should('be.visible')
        .and(allowUnset ? 'be.checked' : 'not.be.checked');
    } else if (type === 'datastream' && aggregation !== 'object') {
      cy.get('#mappingReliability')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', reliability || 'unreliable');
      cy.get('#mappingRetention')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', retention || 'discard');
      cy.get('#mappingDatabaseRetention')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', databaseRetention || 'no_ttl');
      cy.get('#mappingExplicitTimestamp')
        .scrollIntoView()
        .should('be.visible')
        .and(explicitTimestamp ? 'be.checked' : 'not.be.checked');
      if (retention !== 'discard') {
        cy.get('#mappingExpiry')
          .scrollIntoView()
          .should('be.visible')
          .and('have.value', expiry || 0);
      }
      if (databaseRetention !== 'no_ttl') {
        cy.get('#mappingTTL')
          .scrollIntoView()
          .should('be.visible')
          .and('have.value', databaseTTL || 60);
      }
    }
    cy.get('button').contains('Cancel').click();
  });
};

const checkInterfaceEditorUIValues = (iface) => {
  cy.get('#interfaceName')
    .scrollIntoView()
    .should('be.visible')
    .and('have.value', iface.interface_name);
  cy.get('#interfaceMajor')
    .scrollIntoView()
    .should('be.visible')
    .and('have.value', iface.version_major);
  cy.get('#interfaceMinor')
    .scrollIntoView()
    .should('be.visible')
    .and('have.value', iface.version_minor);
  cy.get('#interfaceDescription')
    .scrollIntoView()
    .should('be.visible')
    .and('have.value', iface.description || '');
  cy.get('#interfaceDocumentation')
    .scrollIntoView()
    .should('be.visible')
    .and('have.value', iface.doc || '');
  if (iface.ownership === 'server') {
    cy.get('#interfaceOwnershipServer').scrollIntoView().should('be.visible').and('be.checked');
  } else {
    cy.get('#interfaceOwnershipDevice').scrollIntoView().should('be.visible').and('be.checked');
  }
  if (iface.type === 'properties') {
    cy.get('#interfaceTypeProperties').scrollIntoView().should('be.visible').and('be.checked');
  } else {
    cy.get('#interfaceTypeDatastream').scrollIntoView().should('be.visible').and('be.checked');
    if (iface.aggregation === 'object') {
      cy.get('#interfaceAggregationObject').scrollIntoView().should('be.visible').and('be.checked');
    } else {
      cy.get('#interfaceAggregationIndividual')
        .scrollIntoView()
        .should('be.visible')
        .and('be.checked');
    }
  }
  if (iface.aggregation === 'object') {
    const {
      reliability,
      explicitTimestamp,
      retention,
      expiry,
      databaseRetention,
      databaseTTL,
    } = parseMappingOptions(_.get(iface.mappings, '0'));
    cy.get('#objectMappingReliability')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', reliability || 'unreliable');
    cy.get('#objectMappingExplicitTimestamp')
      .scrollIntoView()
      .should('be.visible')
      .and(explicitTimestamp ? 'be.checked' : 'not.be.checked');
    cy.get('#objectMappingRetention')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', retention || 'discard');
    cy.get('#objectMappingDatabaseRetention')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', databaseRetention || 'no_ttl');
    if (retention !== 'discard') {
      cy.get('#objectMappingExpiry')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', expiry || 0);
    }
    if (databaseRetention !== 'no_ttl') {
      cy.get('#objectMappingTTL')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', databaseTTL || 60);
    }
  }
  (iface.mappings || []).forEach((mapping) => {
    cy.get(`[data-testid="${mapping.endpoint}"]`)
      .contains(mapping.endpoint)
      .scrollIntoView()
      .should('be.visible');
  });
};

describe('Interface builder tests', () => {
  context("without an app's config", () => {
    it('starts up as a standalone Interface Editor', () => {
      cy.dynamicIntercept('getUserConfig', 'GET', '/user-config/config.json', {
        statusCode: 404,
        body: '',
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

      cy.visit('/interfaces/testInterface/0/edit');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
    });

    context('new interface page', () => {
      beforeEach(() => {
        cy.visit('/interfaces/new');
      });

      it('successfully loads New Interface page', function () {
        cy.location('pathname').should('eq', '/interfaces/new');
        cy.get('.main-content h2').contains('Interface Editor');
      });

      it('has a Hide button to toggle Interface Source visibility', () => {
        cy.get('#interfaceSource').scrollIntoView().should('be.visible');
        cy.get('button').contains('Hide source').scrollIntoView().click();
        cy.get('#interfaceSource').should('not.be.visible');
        cy.get('button').contains('Show source').scrollIntoView().click();
        cy.get('#interfaceSource').scrollIntoView().should('be.visible');
      });

      it('correctly displays default and disabled options', () => {
        cy.get('label[for="interfaceName"]').contains('Name');
        cy.get('#interfaceName').should('be.enabled').and('be.empty');
        // default interface version should be 0.1
        cy.get('label[for="interfaceMajor"]').contains('Major');
        cy.get('#interfaceMajor').should('be.enabled').and('have.value', '0');
        cy.get('label[for="interfaceMinor"]').contains('Minor');
        cy.get('#interfaceMinor').should('be.enabled').and('have.value', '1');
        cy.get('label[for="interfaceTypeDatastream"]').contains('Datastream');
        cy.get('#interfaceTypeDatastream').should('be.enabled').and('not.be.checked');
        cy.get('label[for="interfaceTypeProperties"]').contains('Properties');
        cy.get('#interfaceTypeProperties').should('be.enabled').and('be.checked');
        cy.get('label[for="interfaceAggregationIndividual"]').contains('Individual');
        cy.get('#interfaceAggregationIndividual').should('be.disabled');
        cy.get('label[for="interfaceAggregationObject"]').contains('Object');
        cy.get('#interfaceAggregationObject').should('be.disabled');
        cy.get('label[for="interfaceOwnershipDevice"]').contains('Device');
        cy.get('#interfaceOwnershipDevice').should('be.enabled').and('be.checked');
        cy.get('label[for="interfaceOwnershipServer"]').contains('Server');
        cy.get('#interfaceOwnershipServer').should('be.enabled').and('not.be.checked');
        cy.get('label[for="interfaceDescription"]').contains('Description');
        cy.get('#interfaceDescription').should('be.enabled').and('be.empty');
        cy.get('label[for="interfaceDocumentation"]').contains('Documentation');
        cy.get('#interfaceDocumentation').should('be.enabled').and('be.empty');
        cy.get('button').contains('Add new mapping...');

        // Select Datastream type
        cy.get('label').contains('Datastream').click();
        cy.get('#interfaceAggregationIndividual').should('be.enabled').and('be.checked');
        cy.get('#interfaceAggregationObject').should('be.enabled').and('not.be.checked');

        // Select Object type
        cy.get('label').contains('Object').click();

        cy.get('label[for="objectMappingReliability"]').contains('Reliability');
        cy.get('#objectMappingReliability').should('be.enabled').and('have.value', 'unreliable');
        cy.get('label[for="objectMappingExplicitTimestamp"]').contains('Explicit timestamp');
        cy.get('#objectMappingExplicitTimestamp').should('be.enabled').and('be.checked');
        cy.get('label[for="objectMappingRetention"]').contains('Retention');
        cy.get('#objectMappingRetention').should('be.enabled').and('have.value', 'discard');
        cy.get('label[for="objectMappingDatabaseRetention"]').contains('Database Retention');
        cy.get('#objectMappingDatabaseRetention').should('be.enabled').and('have.value', 'no_ttl');

        // Select Volatile retention
        cy.get('#objectMappingRetention').select('volatile');

        cy.get('label[for="objectMappingExpiry"]').contains('Expiry');
        cy.get('#objectMappingExpiry').should('be.enabled').and('have.value', '0');

        // Select use_ttl database retention
        cy.get('#objectMappingDatabaseRetention').select('use_ttl');

        cy.get('label[for="objectMappingTTL"]').contains('TTL');
        cy.get('#objectMappingTTL').should('be.enabled').and('have.value', '60');
      });

      it('displays correct Mapping editor depending on interface type', () => {
        // Properties interface
        cy.get('label').contains('Properties').click();
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add new mapping');
          cy.get('label[for="mappingEndpoint"]').contains('Endpoint');
          cy.get('#mappingEndpoint').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingType"]').contains('Type');
          cy.get('#mappingType').should('be.enabled').and('have.value', 'double');
          cy.get('label[for="mappingAllowUnset"]').contains('Allow unset');
          cy.get('#mappingAllowUnset').should('be.enabled').and('not.be.checked');
          cy.get('label[for="mappingDescription"]').contains('Description');
          cy.get('#mappingDescription').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingDocumentation"]').contains('Documentation');
          cy.get('#mappingDocumentation').should('be.enabled').and('be.empty');
          cy.get('button').contains('Confirm').should('be.disabled');
          cy.get('button').contains('Cancel').click();
        });

        // Datastream Object interface
        cy.get('label').contains('Datastream').click();
        cy.get('label').contains('Object').click();
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add new mapping');
          cy.get('label[for="mappingEndpoint"]').contains('Endpoint');
          cy.get('#mappingEndpoint').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingType"]').contains('Type');
          cy.get('#mappingType').should('be.enabled').and('have.value', 'double');
          cy.get('label[for="mappingDescription"]').contains('Description');
          cy.get('#mappingDescription').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingDocumentation"]').contains('Documentation');
          cy.get('#mappingDocumentation').should('be.enabled').and('be.empty');
          cy.get('button').contains('Confirm').should('be.disabled');
          cy.get('button').contains('Cancel').click();
        });

        // Datastream Individual interface
        cy.get('label').contains('Datastream').click();
        cy.get('label').contains('Individual').click();
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add new mapping');
          cy.get('label[for="mappingEndpoint"]').contains('Endpoint');
          cy.get('#mappingEndpoint').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingType"]').contains('Type');
          cy.get('#mappingType').should('be.enabled').and('have.value', 'double');
          cy.get('label[for="mappingReliability"]').contains('Reliability');
          cy.get('#mappingReliability').should('be.enabled').and('have.value', 'unreliable');
          cy.get('label[for="mappingRetention"]').contains('Retention');
          cy.get('#mappingRetention').should('be.enabled').and('have.value', 'discard');
          cy.get('label[for="mappingDatabaseRetention"]').contains('Database retention');
          cy.get('#mappingDatabaseRetention').should('be.enabled').and('have.value', 'no_ttl');
          cy.get('label[for="mappingExplicitTimestamp"]').contains('Explicit timestamp');
          cy.get('#mappingExplicitTimestamp').should('be.enabled').and('be.checked');
          cy.get('label[for="mappingDescription"]').contains('Description');
          cy.get('#mappingDescription').should('be.enabled').and('be.empty');
          cy.get('label[for="mappingDocumentation"]').contains('Documentation');
          cy.get('#mappingDocumentation').should('be.enabled').and('be.empty');

          // Select Volatile retention
          cy.get('#mappingRetention').select('volatile');
          cy.get('label[for="mappingExpiry"]').contains('Expiry');
          cy.get('#mappingExpiry').should('be.enabled').and('have.value', '0');

          // Select use_ttl database retention
          cy.get('#mappingDatabaseRetention').select('use_ttl');
          cy.get('label[for="mappingTTL"]').contains('TTL');
          cy.get('#mappingTTL').should('be.enabled').and('have.value', '60');

          cy.get('button').contains('Confirm').should('be.disabled');
          cy.get('button').contains('Cancel').click();
        });
      });

      it('can add, edit and remove mappings', () => {
        const mappingEndpoint = '/mapping_endpoint';

        // Add new mapping
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add new mapping');
          cy.get('#mappingEndpoint').paste(mappingEndpoint);
          cy.get('#mappingType').select('double');
          cy.get('button').contains('Confirm').click();
        });
        cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
          cy.contains(mappingEndpoint);
          cy.get('.badge').contains('double');
        });

        // Edit mapping
        cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
          cy.contains(mappingEndpoint);
          cy.get('button').contains('Edit...').click();
        });
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Edit mapping');
          cy.get('#mappingType').select('string');
          cy.get('button').contains('Confirm').click();
        });
        cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
          cy.contains(mappingEndpoint);
          cy.get('.badge').contains('string');
        });

        // Remove mapping
        cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
          cy.contains(mappingEndpoint);
          cy.get('button').contains('Remove').click();
        });
        cy.get(`[data-testid="${mappingEndpoint}"]`).should('not.exist');
      });

      it('shows the correct confirmation modal before installing the interface', () => {
        const interfaceName = 'com.samples.Interface';

        // Set name
        cy.get('#interfaceName').paste(interfaceName);

        // Set draft version
        cy.get('#interfaceMinor').type('{selectall}1');
        cy.get('#interfaceMajor').type('{selectall}0');

        // Add mapping
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add new mapping');
          cy.get('#mappingEndpoint').paste('/enpdoint');
          cy.get('button').contains('Confirm').click();
        });

        // Modal confirmation for draft version
        cy.get('button').contains('Install interface').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Confirmation Required');
          cy.contains(`You are about to install the interface ${interfaceName}.`);
          cy.contains(
            'As its major version is 0, this is a draft interface, which can be deleted.',
          );
          cy.contains('In such a case, any data sent through this interface will be lost.');
          cy.contains('Draft Interfaces should be used for development and testing purposes only.');
          cy.contains('Are you sure you want to continue?');
          cy.get('button').contains('Cancel').click();
        });

        // Set major version
        cy.get('#interfaceMajor').type('{selectall}1');

        // Modal confirmation for major version
        cy.get('button').contains('Install interface').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Confirmation Required');
          cy.contains(`You are about to install the interface ${interfaceName}.`);
          cy.contains(
            'Interface major is greater than zero, that means you will not be able to change already installed mappings.',
          );
          cy.contains('Are you sure you want to continue?');
          cy.get('button').contains('Cancel').click();
        });
      });

      it('correctly reports errors and warning for the interface name property', () => {
        // Empty name
        cy.get('#interfaceName').clear();
        cy.get('#interfaceName').should('have.class', 'is-invalid');

        // Invalid name
        cy.get('#interfaceName').paste('invalid_name!');
        cy.get('#interfaceName').should('have.class', 'is-invalid');

        // Valid but poor name
        cy.get('#interfaceName').clear().paste('name');
        cy.get('#interfaceName').should('not.have.class', 'is-invalid');
        cy.get('#interfaceName')
          .parents('.form-group')
          .get('i.fa-exclamation-circle')
          .should('be.visible');

        // Valid name
        cy.get('#interfaceName').clear().paste('com.sample.Name');
        cy.get('#interfaceName').should('not.have.class', 'is-invalid');
        cy.get('#interfaceName')
          .parents('.form-group')
          .get('i.fa-exclamation-circle')
          .should('not.be.visible');
      });

      it('correctly reports errors in mapping editor for the endpoint field', () => {
        cy.get('button').contains('Add new mapping...').click();
        cy.get('.modal.show').within(() => {
          cy.get('#mappingEndpoint').clear();
          cy.get('#mappingEndpoint').should('have.class', 'is-invalid');
          cy.get('#mappingEndpoint').paste('invalid_endpoint!');
          cy.get('#mappingEndpoint').should('have.class', 'is-invalid');
          cy.get('#mappingEndpoint').clear().paste('/valid_endpoint');
          cy.get('#mappingEndpoint').should('not.have.class', 'is-invalid');
        });
      });

      it('correctly loads interface from its source', () => {
        const interfaceFixtures = [
          'test.astarte.NoDefaultsInterface',
          'test.astarte.PropertiesInterface',
          'test.astarte.IndividualObjectInterface',
          'test.astarte.AggregatedObjectInterface',
        ];
        interfaceFixtures.forEach((interfaceFixture) => {
          cy.fixture(interfaceFixture).then(({ data: iface }) => {
            setupInterfaceEditorFromSource(iface);
            checkInterfaceEditorUIValues(iface);
          });
        });
      });

      it('can correctly build an interface with the UI', () => {
        const interfaceFixtures = [
          'test.astarte.NoDefaultsInterface',
          'test.astarte.PropertiesInterface',
          'test.astarte.IndividualObjectInterface',
          'test.astarte.AggregatedObjectInterface',
        ];
        interfaceFixtures.forEach((interfaceFixture) => {
          cy.fixture(interfaceFixture).then(({ data: iface }) => {
            setupInterfaceEditorFromUI(iface);
            checkInterfaceEditorUIValues(iface);
            (iface.mappings || []).forEach((mapping) => {
              checkMappingEditorUIValues({
                mapping,
                type: iface.type,
                aggregation: iface.aggregation,
              });
            });
          });
        });
      });

      it('redirects to list of interfaces after a new interface installation', () => {
        cy.fixture('test.astarte.PropertiesInterface').then((interfaceFixture) => {
          cy.intercept('POST', '/realmmanagement/v1/*/interfaces', {
            statusCode: 201,
            body: interfaceFixture,
          }).as('installInterfaceRequest');
          setupInterfaceEditorFromUI(interfaceFixture.data);
          cy.get('button').contains('Install interface').click();
          cy.get('.modal.show button').contains('Confirm').click();
          cy.wait('@installInterfaceRequest')
            .its('request.body.data')
            .should('deep.eq', interfaceFixture.data);
          cy.location('pathname').should('eq', '/interfaces');
        });
      });
    });

    context('edit interface page', () => {
      it('correctly loads interface data into the Editor UI', () => {
        const interfaceFixtures = [
          'test.astarte.NoDefaultsInterface',
          'test.astarte.PropertiesInterface',
          'test.astarte.IndividualObjectInterface',
          'test.astarte.AggregatedObjectInterface',
        ];
        interfaceFixtures.forEach((interfaceFixture) => {
          cy.fixture(interfaceFixture).then(({ data: iface }) => {
            cy.intercept(
              'GET',
              `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
              { data: iface },
            );
            cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
            cy.location('pathname').should(
              'eq',
              `/interfaces/${iface.interface_name}/${iface.version_major}/edit`,
            );
            cy.wait(1000);
            checkInterfaceEditorUIValues(iface);
          });
        });
      });

      it('correctly displays fields as disabled to prevent breaking changes from being made', function () {
        cy.fixture('test.astarte.NoDefaultsInterface').then(({ data: iface }) => {
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            { data: iface },
          );
          cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
          cy.wait(1000);
          cy.get('#interfaceName').should('have.attr', 'readonly');
          cy.get('#interfaceMajor').should('have.attr', 'readonly');
          cy.get('#interfaceTypeDatastream').should('be.disabled');
          cy.get('#interfaceTypeProperties').should('be.disabled');
          cy.get('#interfaceAggregationIndividual').should('be.disabled');
          cy.get('#interfaceAggregationObject').should('be.disabled');
          cy.get('#interfaceOwnershipDevice').should('be.disabled');
          cy.get('#interfaceOwnershipServer').should('be.disabled');
          cy.get('#objectMappingReliability').should('be.disabled');
          cy.get('#objectMappingExplicitTimestamp').should('be.disabled');
          cy.get('#objectMappingRetention').should('be.disabled');
          cy.get('#objectMappingExpiry').should('be.disabled');
          cy.get('#objectMappingDatabaseRetention').should('be.disabled');
          cy.get('#objectMappingTTL').should('be.disabled');
          cy.get(`[data-testid="${iface.mappings[0].endpoint}"]`)
            .should('exist')
            .within(() => {
              cy.contains(iface.mappings[0].endpoint);
              cy.get('button').contains('Edit...').should('not.exist');
              cy.get('button').contains('Remove').should('not.exist');
            });
        });
      });

      it('can add, edit and remove new mappings', function () {
        cy.fixture('test.astarte.NoDefaultsInterface').then(({ data: iface }) => {
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            { data: iface },
          );
          cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
          cy.wait(1000);

          const mappingEndpoint = '/new_mapping_endpoint';

          // Add new mapping
          cy.get('button').contains('Add new mapping...').click();
          cy.get('.modal.show').within(() => {
            cy.get('.modal-header').contains('Add new mapping');
            cy.get('#mappingEndpoint').paste(mappingEndpoint);
            cy.get('#mappingType').select('double');
            cy.get('button').contains('Confirm').click();
          });
          cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
            cy.contains(mappingEndpoint);
            cy.get('.badge').contains('double');
          });

          // Edit mapping
          cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
            cy.contains(mappingEndpoint);
            cy.get('button').contains('Edit...').click();
          });
          cy.get('.modal.show').within(() => {
            cy.get('.modal-header').contains('Edit mapping');
            cy.get('#mappingType').select('string');
            cy.get('button').contains('Confirm').click();
          });
          cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
            cy.contains(mappingEndpoint);
            cy.get('.badge').contains('string');
          });

          // Remove mapping
          cy.get(`[data-testid="${mappingEndpoint}"]`).within(() => {
            cy.contains(mappingEndpoint);
            cy.get('button').contains('Remove').click();
          });
          cy.get(`[data-testid="${mappingEndpoint}"]`).should('not.exist');
        });
      });

      it('can only delete a draft Interface', function () {
        const draftInterface = {
          interface_name: 'test.astarte.DraftInterface',
          version_major: 0,
          version_minor: 1,
          type: 'datastream',
          ownership: 'device',
          mappings: [
            {
              endpoint: '/test',
              type: 'double',
            },
          ],
        };
        const majorInterface = _.merge({}, draftInterface, { version_major: 1 });

        cy.intercept(
          'GET',
          `/realmmanagement/v1/*/interfaces/${majorInterface.interface_name}/${majorInterface.version_major}`,
          { data: majorInterface },
        );
        cy.visit(
          `/interfaces/${majorInterface.interface_name}/${majorInterface.version_major}/edit`,
        );
        cy.wait(1000);
        cy.get('button').contains('Delete interface').scrollIntoView().should('not.be.visible');

        cy.intercept(
          'GET',
          `/realmmanagement/v1/*/interfaces/${draftInterface.interface_name}/${draftInterface.version_major}`,
          { data: draftInterface },
        );
        cy.intercept(
          'DELETE',
          `/realmmanagement/v1/*/interfaces/${draftInterface.interface_name}/${draftInterface.version_major}`,
          {
            statusCode: 204,
            body: '',
          },
        ).as('deleteInterfaceRequest');
        cy.visit(
          `/interfaces/${draftInterface.interface_name}/${draftInterface.version_major}/edit`,
        );
        cy.wait(1000);
        cy.get('button').contains('Delete interface').scrollIntoView().click();
        cy.get('.modal.show').within(() => {
          cy.contains(
            `You are going to remove ${draftInterface.interface_name} v${draftInterface.version_major}. This might cause data loss, removed interfaces cannot be restored. Are you sure?`,
          );
          cy.contains(`Please type ${draftInterface.interface_name} to proceed.`);
          cy.get('button').contains('Confirm').should('be.disabled');
          cy.get('#confirmInterfaceName').paste(draftInterface.interface_name);
          cy.get('button').contains('Confirm').should('be.enabled').click();
        });
        cy.wait('@deleteInterfaceRequest');
        cy.location('pathname').should('eq', '/interfaces');
      });

      it('asks to confirm before correctly applying changes', function () {
        cy.fixture('test.astarte.NoDefaultsInterface').then(({ data: iface }) => {
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            { data: iface },
          );
          cy.intercept(
            'PUT',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            {
              statusCode: 204,
              body: '',
            },
          ).as('saveInterfaceRequest');
          cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
          cy.wait(1000);
          const newIface = _.merge({}, iface, {
            version_minor: iface.version_minor + 1,
            doc: 'New documentation',
          });
          cy.get('#interfaceMinor').type(`{selectall}${newIface.version_minor}`);
          cy.get('#interfaceDocumentation').clear().paste(newIface.doc);
          cy.get('button').contains('Apply changes').scrollIntoView().click();
          cy.get('.modal.show').within(() => {
            cy.get('.modal-header').contains('Confirmation Required');
            cy.get('.modal-body').contains(`Update the interface ${newIface.interface_name}?`);
            cy.get('button').contains('Confirm').click();
          });
          cy.wait('@saveInterfaceRequest').its('request.body.data').should('deep.eq', newIface);
        });
      });

      it('displays and saves an interface source with default values stripped out', function () {
        // Case with no default values to strip out
        cy.fixture('test.astarte.NoDefaultsInterface').then(({ data: iface }) => {
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            { data: iface },
          );
          cy.intercept(
            'PUT',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            {
              statusCode: 204,
              body: '',
            },
          ).as('saveNoDefaultsInterfaceRequest');
          cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
          cy.wait(1000);
          const newIface = _.merge({}, iface, {
            version_minor: iface.version_minor + 1,
            doc: 'New documentation',
          });

          // Source should be displayed equal, without adding default values
          cy.get('#interfaceSource')
            .invoke('val')
            .should((ifaceSource) => {
              expect(JSON.parse(ifaceSource)).to.deep.eq(iface);
            });

          cy.get('#interfaceMinor').type(`{selectall}${newIface.version_minor}`);
          cy.get('#interfaceDocumentation').clear().paste(newIface.doc);

          // Source should be displayed equal, without adding default values
          cy.get('#interfaceSource')
            .invoke('val')
            .should((ifaceSource) => {
              expect(JSON.parse(ifaceSource)).to.deep.eq(newIface);
            });

          // Interface should be saved without adding default values
          cy.get('button').contains('Apply changes').scrollIntoView().click();
          cy.get('.modal.show button').contains('Confirm').click();
          cy.wait('@saveNoDefaultsInterfaceRequest')
            .its('request.body.data')
            .should('deep.eq', newIface);
        });

        // Case with default values to strip out
        cy.fixture('test.astarte.SpecifiedDefaultsInterface').then(({ data: iface }) => {
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            { data: iface },
          );
          cy.intercept(
            'PUT',
            `/realmmanagement/v1/*/interfaces/${iface.interface_name}/${iface.version_major}`,
            {
              statusCode: 204,
              body: '',
            },
          ).as('saveSpecifiedDefaultsInterfaceRequest');
          cy.visit(`/interfaces/${iface.interface_name}/${iface.version_major}/edit`);
          cy.wait(1000);
          const newIface = _.merge({}, iface, {
            version_minor: iface.version_minor + 1,
            doc: 'New documentation',
          });

          // Source should not be displayed equal, since default values are stripped out
          cy.get('#interfaceSource')
            .invoke('val')
            .should((ifaceSource) => {
              expect(JSON.parse(ifaceSource)).not.to.deep.eq(iface);
            });

          cy.get('#interfaceMinor').type(`{selectall}${newIface.version_minor}`);
          cy.get('#interfaceDocumentation').clear().paste(newIface.doc);

          // Source should not be displayed equal, since default values are stripped out
          cy.get('#interfaceSource')
            .invoke('val')
            .should((ifaceSource) => {
              expect(JSON.parse(ifaceSource)).not.to.deep.eq(newIface);
            });

          // Interface should be saved with default values stripped out
          cy.get('button').contains('Apply changes').scrollIntoView().click();
          cy.get('.modal.show button').contains('Confirm').click();
          cy.wait('@saveSpecifiedDefaultsInterfaceRequest')
            .its('request.body.data')
            .should('not.deep.eq', newIface);
        });
      });
    });
  });
});
