import _ from 'lodash';

describe('Device page tests', () => {
  context('no access before login', () => {
    before(() => {
      cy.fixture('device').as('device');
    });

    it('redirects to login', function () {
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.fixture('device').as('device');
      cy.fixture('device_detailed').as('deviceDetailed');
      cy.intercept('POST', '/appengine/v1/*/groups/*/devices', {
        statusCode: 201,
        body: '',
      }).as('updateGroupRequest');
      cy.login();
    });

    it('successfully loads Device page', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device' });
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.location('pathname').should('eq', `/devices/${this.device.data.id}/edit`);
      cy.get('h2').contains('Device');
    });

    it('displays correct properties for a device', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device' });
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.contains('Device Info')
          .next()
          .within(() => {
            cy.contains('Device ID').next().contains(this.device.data.id);
            cy.contains('Device name').next().contains('No name alias set');
            cy.contains('Status').next().contains('Never connected');
            cy.contains('Credentials inhibited').next().contains('False');
            cy.contains('Inhibit credentials').should('exist').and('not.be.disabled');
            cy.contains('Enable credentials request').should('not.exist');
            cy.contains('Wipe credential secret').should('exist').and('not.be.disabled');
          });

        cy.contains('Aliases')
          .next()
          .within(() => {
            cy.contains('Device has no aliases');
            cy.contains('Add new alias').should('exist').and('not.be.disabled');
          });

        cy.contains('Metadata')
          .next()
          .within(() => {
            cy.contains('Device has no metadata');
            cy.contains('Add new item').should('exist').and('not.be.disabled');
          });

        cy.contains('Groups')
          .next()
          .within(() => {
            cy.contains('Device does not belong to any group');
            cy.contains('Add to existing group').should('exist').and('not.be.disabled');
          });

        cy.contains('Interfaces')
          .next()
          .within(() => {
            cy.contains('No introspection info');
          });

        cy.contains('Previous Interfaces')
          .next()
          .within(() => {
            cy.contains('No previous interfaces info');
          });

        cy.contains('Device Stats');

        cy.contains('Device Status Events');

        cy.contains('Device Live Events');
      });
    });

    it('successfully loads Device page for a detailed device', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
      cy.visit(`/devices/${this.deviceDetailed.data.id}/edit`);
      cy.location('pathname').should('eq', `/devices/${this.deviceDetailed.data.id}/edit`);
      cy.get('h2').contains('Device');
    });

    it('displays correct properties for a detailed device', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
      cy.visit(`/devices/${this.deviceDetailed.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.contains('Device Info')
          .next()
          .within(() => {
            cy.contains('Device ID').next().contains(this.deviceDetailed.data.id);
            cy.contains('Device name').next().contains(this.deviceDetailed.data.aliases.name);
            cy.contains('Status').next().contains('Connected');
            cy.contains('Credentials inhibited').next().contains('True');
            cy.contains('Enable credentials request').should('not.be.disabled');
            cy.contains('Inhibit credentials').should('not.exist');
            cy.contains('Wipe credential secret').should('not.be.disabled');
          });

        cy.contains('Aliases')
          .next()
          .within(() => {
            Object.entries(this.deviceDetailed.data.aliases).forEach(([aliasKey, aliasValue]) => {
              cy.contains(aliasKey).next().contains(aliasValue);
            });
            cy.contains('Add new alias').should('not.be.disabled');
          });

        cy.contains('Metadata')
          .next()
          .within(() => {
            Object.entries(this.deviceDetailed.data.metadata).forEach(
              ([metadataKey, metadataValue]) => {
                cy.contains(metadataKey).next().contains(metadataValue);
              },
            );
            cy.contains('Add new item').should('not.be.disabled');
          });

        cy.contains('Groups')
          .next()
          .within(() => {
            this.deviceDetailed.data.groups.forEach((group) => {
              cy.contains(group).should('have.attr', 'href', `/groups/${group}/edit`);
            });
            cy.contains('Add to existing group').should('not.be.disabled');
          });

        cy.contains('Interfaces')
          .next()
          .within(() => {
            Object.entries(this.deviceDetailed.data.introspection).forEach(([interfaceName]) => {
              cy.contains(interfaceName);
            });
          });

        cy.contains('Previous Interfaces')
          .next()
          .within(() => {
            this.deviceDetailed.data.previous_interfaces.forEach((interface) => {
              cy.contains(interface.name);
            });
          });

        cy.contains('Device Stats');

        cy.contains('Device Status Events')
          .next()
          .within(() => {
            cy.contains('Last seen IP').next().contains(this.deviceDetailed.data.last_seen_ip);
            cy.contains('Last credentials request IP')
              .next()
              .contains(this.deviceDetailed.data.last_credentials_request_ip);
            cy.contains('First credentials request');
            cy.contains('First registration');
            cy.contains('Last connection');
            cy.contains('Last disconnection');
          });

        cy.contains('Device Live Events');
      });
    });

    it('correctly inhibit credentials request', function () {
      const deviceWithInhibitedCredentials = _.merge({}, this.device, {
        data: { credentials_inhibited: true },
      });
      const deviceWithoutInhibitedCredentials = _.merge({}, this.device, {
        data: { credentials_inhibited: false },
      });
      cy.intercept('GET', '/appengine/v1/*/devices/*', deviceWithoutInhibitedCredentials);
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.get('.main-content .card-header')
        .contains('Device Info')
        .parents('.card')
        .within(() => {
          cy.contains('Credentials inhibited').next().contains('False');
          cy.contains('Enable credentials request').should('not.exist');
          cy.contains('Inhibit credentials').should('exist').and('not.be.disabled');
          cy.intercept('PATCH', '/appengine/v1/*/devices/*', deviceWithInhibitedCredentials).as(
            'updateDeviceRequest',
          );
          cy.intercept('GET', '/appengine/v1/*/devices/*', deviceWithInhibitedCredentials);
          cy.contains('Inhibit credentials').click();
          cy.wait('@updateDeviceRequest')
            .its('request.body')
            .then((body) => JSON.parse(body).data.credentials_inhibited)
            .should('deep.eq', true);
          cy.contains('Credentials inhibited').next().contains('True');
          cy.contains('Enable credentials request').should('exist').and('not.be.disabled');
          cy.contains('Inhibit credentials').should('not.exist');
        });
    });

    it('correctly enable credentials request', function () {
      const deviceWithInhibitedCredentials = _.merge({}, this.device, {
        data: { credentials_inhibited: true },
      });
      const deviceWithoutInhibitedCredentials = _.merge({}, this.device, {
        data: { credentials_inhibited: false },
      });
      cy.intercept('GET', '/appengine/v1/*/devices/*', deviceWithInhibitedCredentials);
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.get('.main-content .card-header')
        .contains('Device Info')
        .parents('.card')
        .within(() => {
          cy.contains('Credentials inhibited').next().contains('True');
          cy.contains('Enable credentials request').should('exist').and('not.be.disabled');
          cy.contains('Inhibit credentials').should('not.exist');
          cy.intercept('PATCH', '/appengine/v1/*/devices/*', deviceWithoutInhibitedCredentials).as(
            'updateDeviceRequest',
          );
          cy.intercept('GET', '/appengine/v1/*/devices/*', deviceWithoutInhibitedCredentials);
          cy.contains('Enable credentials request').click();
          cy.wait('@updateDeviceRequest')
            .its('request.body')
            .then((body) => JSON.parse(body).data.credentials_inhibited)
            .should('deep.eq', false);
          cy.contains('Credentials inhibited').next().contains('False');
          cy.contains('Enable credentials request').should('not.exist');
          cy.contains('Inhibit credentials').should('exist').and('not.be.disabled');
        });
    });

    it('asks confirmation before wiping credentials secret', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device' });
      cy.intercept('DELETE', `/pairing/v1/*/agent/devices/${this.device.data.id}`, {
        statusCode: 204,
        body: '',
      }).as('wipeCredentialsSecretRequest');
      cy.visit(`/devices/${this.device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.contains('Wipe credential secret').should('exist').and('not.be.disabled').click();
        cy.get('.modal').contains(
          'This will remove the current device credential secret from Astarte, forcing the device to register again and store its new credentials secret. Continue?',
        );
        cy.get('.modal').contains('Wipe credentials secret').click();
        cy.wait('@wipeCredentialsSecretRequest');
        cy.get('.modal')
          .contains(
            "The device's credentials secret was wiped from Astarte. You can click here to register the device again and retrieve its new credentials secret.",
          )
          .contains('click here')
          .should('have.attr', 'href')
          .then((href) => {
            expect(href.endsWith(`/devices/register?deviceId=${this.device.data.id}`)).to.be.true;
          });
        cy.get('.modal button').contains('OK').click();
      });
    });

    it('correctly adds a device alias', function () {
      const device = _.merge({}, this.device);
      device.data.aliases = {};
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.aliases = { alias_key: 'alias_value' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.contains('Add new alias').should('exist').and('not.be.disabled').click();
          });
        cy.get('.modal-header')
          .contains('Add New Alias')
          .parents('.modal')
          .within(() => {
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.get('input#key').type('alias_key');
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.get('input#value').type('alias_value');
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Confirm').should('not.be.disabled').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { aliases: { alias_key: 'alias_value' } });
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('alias_key');
            cy.contains('alias_value');
          });
      });
    });

    it('correctly removes a device alias', function () {
      const device = _.merge({}, this.device);
      device.data.aliases = { alias_key1: 'alias_value1', alias_key2: 'alias_value2' };
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.aliases = { alias_key1: 'alias_value1' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 2);
            cy.contains('alias_key1');
            cy.contains('alias_value1');
            cy.contains('alias_key2');
            cy.contains('alias_value2');
            cy.get('table tbody tr:nth(1) i.fa-eraser').click();
          });
        cy.get('.modal-header')
          .contains('Delete Alias')
          .parents('.modal')
          .within(() => {
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Delete').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { aliases: { alias_key2: null } });
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('alias_key1');
            cy.contains('alias_value1');
          });
      });
    });

    it('correctly edits a device alias', function () {
      const device = _.merge({}, this.device);
      device.data.aliases = { alias_key: 'alias_value' };
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.aliases = { alias_key: 'alias_new_value' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('alias_key');
            cy.contains('alias_value');
            cy.get('table tbody tr:nth(0) i.fa-pencil-alt').click();
          });
        cy.get('.modal-header')
          .contains('Edit "alias_key"')
          .parents('.modal')
          .within(() => {
            cy.get('input#value').clear();
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.get('input#value').type('alias_new_value');
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Confirm').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { aliases: { alias_key: 'alias_new_value' } });
        cy.get('.card-header')
          .contains('Aliases')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('alias_key');
            cy.contains('alias_new_value');
          });
      });
    });

    it('correctly adds a device metadata', function () {
      const device = _.merge({}, this.device);
      device.data.metadata = {};
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.metadata = { metadata_key: 'metadata_value' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.contains('Add new item').should('exist').and('not.be.disabled').click();
          });
        cy.get('.modal-header')
          .contains('Add New Item')
          .parents('.modal')
          .within(() => {
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.get('input#key').type('metadata_key');
            cy.get('button').contains('Confirm').should('not.be.disabled');
            cy.get('input#value').type('metadata_value');
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Confirm').should('not.be.disabled').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { metadata: { metadata_key: 'metadata_value' } });
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('metadata_key');
            cy.contains('metadata_value');
          });
      });
    });

    it('correctly removes a device metadata', function () {
      const device = _.merge({}, this.device);
      device.data.metadata = { metadata_key1: 'metadata_value1', metadata_key2: 'metadata_value2' };
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.metadata = { metadata_key1: 'metadata_value1' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 2);
            cy.contains('metadata_key1');
            cy.contains('metadata_value1');
            cy.contains('metadata_key2');
            cy.contains('metadata_value2');
            cy.get('table tbody tr:nth(1) i.fa-eraser').click();
          });
        cy.get('.modal-header')
          .contains('Delete Item')
          .parents('.modal')
          .within(() => {
            cy.contains('Do you want to delete metadata_key2 from metadata?');
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Delete').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { metadata: { metadata_key2: null } });
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('metadata_key1');
            cy.contains('metadata_value1');
          });
      });
    });

    it('correctly edits a device metadata', function () {
      const device = _.merge({}, this.device);
      device.data.metadata = { metadata_key: 'metadata_value' };
      const updatedDevice = _.merge({}, this.device);
      updatedDevice.data.metadata = { metadata_key: 'metadata_new_value' };
      cy.intercept('GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('metadata_key');
            cy.contains('metadata_value');
            cy.get('table tbody tr:nth(0) i.fa-pencil-alt').click();
          });
        cy.get('.modal-header')
          .contains('Edit "metadata_key"')
          .parents('.modal')
          .within(() => {
            cy.get('input#value').clear();
            cy.get('button').contains('Confirm').should('not.be.disabled');
            cy.get('input#value').type('metadata_new_value');
            cy.intercept('GET', '/appengine/v1/*/devices/*', updatedDevice);
            cy.intercept('PATCH', '/appengine/v1/*/devices/*', updatedDevice).as(
              'updateDeviceRequest',
            );
            cy.get('button').contains('Confirm').click();
          });
        cy.wait('@updateDeviceRequest')
          .its('request.body')
          .then((body) => JSON.parse(body).data)
          .should('deep.eq', { metadata: { metadata_key: 'metadata_new_value' } });
        cy.get('.card-header')
          .contains('Metadata')
          .parents('.card')
          .within(() => {
            cy.get('table tbody').find('tr').should('have.length', 1);
            cy.contains('metadata_key');
            cy.contains('metadata_new_value');
          });
      });
    });

    it('correctly adds to new group', function () {
      const deviceGroups = ['group1', 'group2'];
      const allGroups = ['group1', 'group2', 'group3', 'group4'];
      const device = _.merge({}, this.deviceDetailed);
      device.data.groups = deviceGroups;
      const updatedDevice = _.merge({}, this.deviceDetailed);
      updatedDevice.data.groups = deviceGroups.concat('group3');
      cy.intercept('GET', '/appengine/v1/*/groups', { data: allGroups });
      cy.dynamicIntercept('getDeviceRequest', 'GET', '/appengine/v1/*/devices/*', device);
      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Groups')
          .parents('.card')
          .within(() => {
            cy.get('table tbody tr').should('have.length', deviceGroups.length);
            cy.contains('Add to existing group').click();
          });
        cy.get('.modal-header')
          .contains('Select Existing Group')
          .parents('.modal')
          .within(() => {
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.contains('group3').click();
            cy.dynamicIntercept(
              'getDeviceRequest',
              'GET',
              '/appengine/v1/*/devices/*',
              updatedDevice,
            );
            cy.get('button').contains('Confirm').click();
          });
        cy.wait(['@updateGroupRequest', '@getDeviceRequest']);
        cy.get('.card-header')
          .contains('Groups')
          .parents('.card')
          .within(() => {
            cy.get('table tbody tr').should('have.length', deviceGroups.length + 1);
            cy.contains('group3');
          });
      });
    });

    it('correctly adds the device to a group with symbols in its name', function () {
      const groupName = '!"£$%&/()=?^';
      const deviceGroups = ['group1', 'group2'];
      const allGroups = deviceGroups.concat(groupName);
      const device = _.merge({}, this.deviceDetailed);
      device.data.groups = deviceGroups;
      const updatedDevice = _.merge({}, this.deviceDetailed);
      updatedDevice.data.groups = allGroups;
      cy.dynamicIntercept('getDeviceRequest', 'GET', '/appengine/v1/*/devices/*', device);
      cy.intercept('GET', '/appengine/v1/*/groups', { data: allGroups });

      cy.visit(`/devices/${device.data.id}/edit`);
      cy.get('.main-content').within(() => {
        cy.get('.card-header')
          .contains('Groups')
          .parents('.card')
          .within(() => {
            cy.get('table tbody tr').should('have.length', deviceGroups.length);
            cy.contains('Add to existing group').click();
          });
        cy.get('.modal-header')
          .contains('Select Existing Group')
          .parents('.modal')
          .within(() => {
            cy.get('button').contains('Confirm').should('be.disabled');
            cy.contains(groupName).click();
            cy.dynamicIntercept(
              'getDeviceRequest',
              'GET',
              '/appengine/v1/*/devices/*',
              updatedDevice,
            );
            cy.get('button').contains('Confirm').click();
          });
        cy.wait(['@updateGroupRequest', '@getDeviceRequest']);
        cy.get('.card-header')
          .contains('Groups')
          .parents('.card')
          .within(() => {
            cy.contains(groupName);
          });
      });
    });

    it('correctly renders Device Stats', function () {
      cy.intercept('GET', '/appengine/v1/*/devices/*', { fixture: 'device_detailed' });
      cy.visit(`/devices/${this.deviceDetailed.data.id}/edit`);

      const formatBytes = (bytes) => {
        if (bytes < 1024) {
          return bytes + 'B';
        }
        if (bytes < 1024 * 1024) {
          return (bytes / 1024).toFixed(2) + 'KiB';
        }
        return (bytes / (1024 * 1024)).toFixed(2) + 'MiB';
      };

      cy.get('.card-header')
        .contains('Device Stats')
        .parents('.card')
        .within(() => {
          const currentInterfaces = Object.entries(
            this.deviceDetailed.data.introspection,
          ).map(([name, interface]) => ({ name, ...interface }));
          const previousInterfaces = this.deviceDetailed.data.previous_interfaces;
          const interfaces = [...currentInterfaces, ...previousInterfaces];
          cy.get('table tbody tr').should('have.length', interfaces.length + 2);
          interfaces.forEach((interface) => {
            cy.contains(`${interface.name} v${interface.major}.${interface.minor}`)
              .parents('tr')
              .within(() => {
                cy.contains(formatBytes(interface.exchanged_bytes));
                cy.contains(interface.exchanged_msgs);
              });
          });
          const totalBytes = this.deviceDetailed.data.total_received_bytes;
          const totalMessages = this.deviceDetailed.data.total_received_msgs;
          const interfacesBytes = _.sumBy(interfaces, 'exchanged_bytes');
          const interfacesMessages = _.sumBy(interfaces, 'exchanged_msgs');
          const otherBytes = totalBytes - interfacesBytes;
          const otherMessages = totalMessages - interfacesMessages;
          cy.get(`table tbody tr:nth-child(${interfaces.length + 1})`).within(() => {
            cy.contains('Other');
            cy.contains(formatBytes(otherBytes));
            cy.contains(otherMessages);
          });
          cy.get(`table tbody tr:nth-child(${interfaces.length + 2})`).within(() => {
            cy.contains('Total');
            cy.contains(formatBytes(totalBytes));
            cy.contains(totalMessages);
          });
          cy.get('svg.device-data-piechart').scrollIntoView().should('be.visible');
        });
    });

    it('correctly displays live messages', function () {
      cy.fixture('config/https').then((config) => {
        const wssUrl =
          config.astarte_api_url.replace('https://', 'wss://') + '/appengine/v1/socket/websocket';
        cy.intercept('GET', '/appengine/v1/*/devices/*', this.device);
        cy.mockWebSocket({ url: wssUrl });
        cy.visit(`/devices/${this.device.data.id}/edit`);
        cy.get('.main-content .card-header')
          .contains('Device Live Events')
          .parents('.card')
          .within(() => {
            cy.contains(`Joined room for device ${this.device.data.id}`);
            cy.contains('Watching for device connection events');
            cy.contains('Watching for device disconnection events');
            cy.contains('Watching for device error events');
            cy.contains('Watching for device data events');

            cy.sendWebSocketDeviceConnected({
              deviceId: this.device.data.id,
              deviceIpAddress: '1.2.3.4',
            });
            cy.contains('device connected');
            cy.contains('IP : 1.2.3.4');

            cy.sendWebSocketDeviceDisconnected({ deviceId: this.device.data.id });
            cy.contains('device disconnected');
            cy.contains('Device disconnected');

            cy.sendWebSocketDeviceEvent({
              deviceId: this.device.data.id,
              event: {
                type: 'incoming_data',
                interface: 'com.domain.InterfaceName1',
                path: '/some/endpoint1',
                value: 42,
              },
            });
            cy.contains('incoming data');
            cy.contains('com.domain.InterfaceName1');
            cy.contains('/some/endpoint1');
            cy.contains('42');

            cy.sendWebSocketDeviceEvent({
              deviceId: this.device.data.id,
              event: {
                type: 'incoming_data',
                interface: 'com.domain.InterfaceName2',
                path: '/some/endpoint2',
                value: null,
              },
            });
            cy.contains('unset property');
            cy.contains('com.domain.InterfaceName2');
            cy.contains('/some/endpoint2');

            const deviceErrors = [
              {
                name: 'write_on_server_owned_interface',
                label: 'Write on a server owned interface',
              },
              {
                name: 'invalid_interface',
                label: 'Invalid interface',
              },
              {
                name: 'invalid_path',
                label: 'Invalid path',
              },
              {
                name: 'mapping_not_found',
                label: 'Mapping not found',
              },
              {
                name: 'interface_loading_failed',
                label: 'Interface loading failed',
              },
              {
                name: 'ambiguous_path',
                label: 'Ambiguous path',
              },
              {
                name: 'undecodable_bson_payload',
                label: 'Undecodable BSON payload',
              },
              {
                name: 'unexpected_value_type',
                label: 'Unexpected value type',
              },
              {
                name: 'value_size_exceeded',
                label: 'Value size exceeded',
              },
              {
                name: 'unexpected_object_key',
                label: 'Unexpected object key',
              },
              {
                name: 'invalid_introspection',
                label: 'Invalid introspection',
              },
              {
                name: 'unexpected_control_message',
                label: 'Unexpected control message',
              },
              {
                name: 'device_session_not_found',
                label: 'Device session not found',
              },
              {
                name: 'resend_interface_properties_failed',
                label: 'Resend interface properties failed',
              },
              {
                name: 'empty_cache_error',
                label: 'Empty cache error',
              },
            ];
            deviceErrors.forEach((deviceError) => {
              cy.sendWebSocketDeviceEvent({
                deviceId: this.device.data.id,
                event: {
                  type: 'device_error',
                  error_name: deviceError.name,
                  metadata: {
                    meta_key: 'meta_value',
                  },
                },
              });
              cy.contains('device error');
              cy.contains(deviceError.label);
            });
          });
      });
    });
  });
});
