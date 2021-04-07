const triggerConditionToLabel = {
  device_connected: 'Device Connected',
  device_disconnected: 'Device Disconnected',
  device_error: 'Device Error',
  device_empty_cache_received: 'Empty Cache Received',
  incoming_data: 'Incoming Data',
  value_change: 'Value Change',
  value_change_applied: 'Value Change Applied',
  path_created: 'Path Created',
  path_removed: 'Path Removed',
  value_stored: 'Value Stored',
};

const triggerOperatorToLabel = {
  '*': '*',
  '==': '==',
  '!=': '!=',
  '>': '>',
  '>=': '>=',
  '<': '<',
  '<=': '<=',
  contains: 'Contains',
  not_contains: 'Not Contains',
};

const setupTriggerEditorFromSource = (trigger) => {
  cy.get('#triggerSource').scrollIntoView().paste(JSON.stringify(trigger));
  cy.wait(1500);
};

const checkTriggerEditorUIValues = (trigger) => {
  const simpleTrigger = trigger.simple_triggers[0];
  cy.get('#triggerName').scrollIntoView().should('be.visible').and('have.value', trigger.name);
  cy.get('#triggerCondition')
    .scrollIntoView()
    .should('be.visible')
    .contains(triggerConditionToLabel[simpleTrigger.on])
    .should('be.selected');

  const isDataTrigger = simpleTrigger.type === 'data_trigger';
  cy.get('#triggerSimpleTriggerType')
    .scrollIntoView()
    .should('be.visible')
    .contains(isDataTrigger ? 'Data Trigger' : 'Device Trigger')
    .should('be.selected');

  if (simpleTrigger.device_id) {
    cy.get('#triggerTargetSelect')
      .scrollIntoView()
      .should('be.visible')
      .contains('Device')
      .should('be.selected');
    cy.get('#triggerDeviceId')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', simpleTrigger.device_id);
  } else if (simpleTrigger.group_name) {
    cy.get('#triggerTargetSelect')
      .scrollIntoView()
      .should('be.visible')
      .contains('Group')
      .should('be.selected');
    cy.get('#triggerGroupName')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', simpleTrigger.group_name);
  } else {
    cy.get('#triggerTargetSelect')
      .scrollIntoView()
      .should('be.visible')
      .contains('All devices')
      .should('be.selected');
  }

  if (isDataTrigger) {
    const iface = simpleTrigger.interface_name;
    if (iface === '*') {
      cy.get('#triggerInterfaceName')
        .scrollIntoView()
        .should('be.visible')
        .contains('Any interface')
        .should('be.selected');
    } else {
      cy.get('#triggerInterfaceName')
        .scrollIntoView()
        .should('be.visible')
        .contains(iface)
        .should('be.selected');
      cy.get('#triggerInterfaceMajor')
        .scrollIntoView()
        .should('be.visible')
        .contains(simpleTrigger.interface_major)
        .should('be.selected');
      cy.get('#triggerPath')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', simpleTrigger.match_path);
      if (simpleTrigger.value_match_operator) {
        cy.get('#triggerOperator')
          .scrollIntoView()
          .should('be.visible')
          .contains(triggerOperatorToLabel[simpleTrigger.value_match_operator])
          .should('be.selected');
      }
      if (simpleTrigger.known_value != null) {
        cy.get('#triggerKnownValue')
          .scrollIntoView()
          .should('be.visible')
          .and('have.value', simpleTrigger.known_value);
      }
    }
  }

  const isHttpAction = !!trigger.action.http_url;
  cy.get('#triggerActionType')
    .scrollIntoView()
    .should('be.visible')
    .contains(isHttpAction ? 'HTTP request' : 'AMQP Message')
    .should('be.selected');

  if (isHttpAction) {
    cy.get('#triggerMethod')
      .scrollIntoView()
      .should('be.visible')
      .contains(trigger.action.http_method.toUpperCase())
      .should('be.selected');
    cy.get('#triggerUrl')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', trigger.action.http_url);
    cy.get('#actionIgnoreSSLErrors')
      .scrollIntoView()
      .should('be.visible')
      .and(trigger.action.ignore_ssl_errors ? 'be.checked' : 'not.be.checked');
    const hasMustacheTemplate = trigger.action.template_type === 'mustache';
    cy.get('#triggerTemplateType')
      .should('be.visible')
      .contains(hasMustacheTemplate ? 'Mustache' : 'Use default event format (JSON)')
      .should('be.selected');
    if (hasMustacheTemplate) {
      cy.get('#actionPayload')
        .scrollIntoView()
        .should('be.visible')
        .and('have.value', trigger.action.template);
    }
    Object.entries(trigger.action.http_static_headers || {}).forEach(
      ([headerName, headerValue]) => {
        cy.get('table tr').contains(headerName).scrollIntoView().should('be.visible');
        cy.get('table tr').contains(headerValue).scrollIntoView().should('be.visible');
      },
    );
  }

  if (!isHttpAction) {
    // AMQP action
    cy.get('#amqpExchange')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', trigger.action.amqp_exchange);
    cy.get('#amqpRoutingKey')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', trigger.action.amqp_routing_key || '');
    cy.get('#amqpPersistency')
      .scrollIntoView()
      .should('be.visible')
      .and(trigger.action.amqp_message_persistent ? 'be.checked' : 'not.be.checked');
    cy.get('#amqpPriority')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', trigger.action.amqp_message_priority || 0);
    cy.get('#amqpExpiration')
      .scrollIntoView()
      .should('be.visible')
      .and('have.value', trigger.action.amqp_message_expiration_ms || 0);
    Object.entries(trigger.action.amqp_static_headers || {}).forEach(
      ([headerName, headerValue]) => {
        cy.get('table tr').contains(headerName).scrollIntoView().should('be.visible');
        cy.get('table tr').contains(headerValue).scrollIntoView().should('be.visible');
      },
    );
  }
};

const checkTriggerEditorUIDisabledOptions = (trigger) => {
  const simpleTrigger = trigger.simple_triggers[0];
  cy.get('#triggerName').should('have.attr', 'readonly');
  cy.get('#triggerCondition').should('be.disabled');
  cy.get('#triggerSimpleTriggerType').should('be.disabled');
  const isDataTrigger = simpleTrigger.type === 'data_trigger';

  cy.get('#triggerTargetSelect').should('be.disabled');
  if (simpleTrigger.device_id) {
    cy.get('#triggerDeviceId').should('have.attr', 'readonly');
  } else if (simpleTrigger.group_name) {
    cy.get('#triggerGroupName').should('have.attr', 'readonly');
  }

  if (isDataTrigger) {
    const iface = simpleTrigger.interface_name;
    cy.get('#triggerInterfaceName').should('be.disabled');
    if (iface !== '*') {
      cy.get('#triggerInterfaceMajor').should('be.disabled');
      cy.get('#triggerPath').should('have.attr', 'readonly');
      if (simpleTrigger.value_match_operator) {
        cy.get('#triggerOperator').should('be.disabled');
      }
      if (simpleTrigger.known_value != null) {
        cy.get('#triggerKnownValue').should('have.attr', 'readonly');
      }
    }
  }

  const isHttpAction = !!trigger.action.http_url;
  cy.get('#triggerActionType').should('be.disabled');

  if (isHttpAction) {
    cy.get('#triggerMethod').should('be.disabled');
    cy.get('#triggerUrl').should('have.attr', 'readonly');
    cy.get('#actionIgnoreSSLErrors').should('be.disabled');
    cy.get('#triggerTemplateType').should('be.disabled');
    const hasMustacheTemplate = trigger.action.template_type === 'mustache';
    if (hasMustacheTemplate) {
      cy.get('#actionPayload').should('have.attr', 'readonly');
    }
    Object.keys(trigger.action.http_static_headers || {}).forEach((headerName) => {
      cy.get('table tr')
        .contains(headerName)
        .parents('tr')
        .get('i.fa-pencil-alt')
        .should('not.exist');
      cy.get('table tr').contains(headerName).parents('tr').get('i.fa-eraser').should('not.exist');
    });
  }

  if (!isHttpAction) {
    // AMQP action
    cy.get('#amqpExchange').should('have.attr', 'readonly');
    cy.get('#amqpRoutingKey').should('have.attr', 'readonly');
    cy.get('#amqpPersistency').should('be.disabled');
    cy.get('#amqpPriority').should('have.attr', 'readonly');
    cy.get('#amqpExpiration').should('have.attr', 'readonly');
    Object.keys(trigger.action.amqp_static_headers || {}).forEach((headerName) => {
      cy.get('table tr')
        .contains(headerName)
        .parents('tr')
        .get('i.fa-pencil-alt')
        .should('not.exist');
      cy.get('table tr').contains(headerName).parents('tr').get('i.fa-eraser').should('not.exist');
    });
  }
};

describe('Trigger builder tests', () => {
  context('no access before login', () => {
    it('redirects to login', () => {
      cy.visit('/triggers/new');
      cy.location('pathname').should('eq', '/login');

      cy.visit('/triggers/testTrigger/edit');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(() => {
      cy.login();
      cy.fixture('realm').as('realm');
      cy.fixture('interfaces').as('interfaces');
      cy.fixture('interface_majors').as('interface_majors');
      cy.fixture('test.astarte.FirstInterface').as('first_interface');
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces', { fixture: 'interfaces' });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces/test.astarte.FirstInterface', {
        fixture: 'interface_majors',
      });
      cy.intercept('GET', '/realmmanagement/v1/*/interfaces/test.astarte.FirstInterface/*', {
        fixture: 'test.astarte.FirstInterface',
      });
      cy.fixture('test.astarte.AggregatedObjectInterface')
        .as('datastream_object_interface')
        .then((iface) => {
          cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${iface.data.interface_name}`, {
            data: [iface.data.version_major],
          });
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.data.interface_name}/${iface.data.version_major}`,
            iface,
          );
        });
      cy.fixture('test.astarte.PropertiesInterface')
        .as('properties_interface')
        .then((iface) => {
          cy.intercept('GET', `/realmmanagement/v1/*/interfaces/${iface.data.interface_name}`, {
            data: [iface.data.version_major],
          });
          cy.intercept(
            'GET',
            `/realmmanagement/v1/*/interfaces/${iface.data.interface_name}/${iface.data.version_major}`,
            iface,
          );
        });
    });

    context('new trigger page', () => {
      beforeEach(() => {
        cy.visit('/triggers/new');
        cy.wait(1000);
      });

      it('successfully loads New Trigger page', function () {
        cy.location('pathname').should('eq', '/triggers/new');
        cy.get('.main-content h2').contains('Trigger Editor');
        cy.get('#triggerName').should('have.value', '');
      });

      it('has a Hide button to toggle Trigger Source visibility', () => {
        cy.get('#triggerSource').scrollIntoView().should('be.visible');
        cy.get('button').contains('Hide source').scrollIntoView().click();
        cy.get('#triggerSource').should('not.exist');
        cy.get('button').contains('Show source').scrollIntoView().click();
        cy.get('#triggerSource').scrollIntoView().should('be.visible');
      });

      it('correctly displays default and disabled options', function () {
        cy.get('label[for="triggerName"]').contains('Name');
        cy.get('#triggerName').should('be.enabled').and('be.empty');
        cy.get('label[for="triggerSimpleTriggerType"]').contains('Trigger type');
        cy.get('#triggerSimpleTriggerType')
          .should('be.enabled')
          .contains('Data Trigger')
          .should('be.selected');

        cy.get('label[for="triggerTargetSelect"]').contains('Target');
        cy.get('#triggerTargetSelect')
          .should('be.enabled')
          .contains('All devices')
          .should('be.selected');
        cy.get('#triggerTargetSelect').select('Device');
        cy.get('label[for="triggerDeviceId"]').contains('Device id');
        cy.get('#triggerDeviceId').should('be.enabled').and('be.empty');
        cy.get('#triggerTargetSelect').select('Group');
        cy.get('label[for="triggerGroupName"]').contains('Group Name');
        cy.get('#triggerGroupName').should('be.enabled').and('be.empty');

        cy.get('label[for="triggerInterfaceName"]').contains('Interface name');
        cy.get('#triggerInterfaceName')
          .should('be.enabled')
          .contains('Any interface')
          .should('be.selected');
        cy.get('#triggerInterfaceName').select(this.first_interface.data.interface_name);
        cy.get('label[for="triggerInterfaceMajor"]').contains('Interface major');
        cy.get('#triggerInterfaceMajor')
          .should('be.enabled')
          .contains(this.first_interface.data.version_major)
          .should('be.selected');
        cy.get('label[for="triggerCondition"]').contains('Trigger condition');
        cy.get('#triggerCondition')
          .should('be.enabled')
          .contains('Incoming Data')
          .should('be.selected');
        cy.get('label[for="triggerPath"]').contains('Path');
        cy.get('#triggerPath').should('be.enabled').and('have.value', '/*');
        cy.get('label[for="triggerOperator"]').contains('Operator');
        cy.get('#triggerOperator').should('be.enabled').contains('*').should('be.selected');
        cy.get('label[for="triggerActionType"]').contains('Action type');
        cy.get('#triggerActionType')
          .should('be.enabled')
          .contains('HTTP request')
          .should('be.selected');
        cy.get('label[for="triggerMethod"]').contains('Method');
        cy.get('#triggerMethod').should('be.enabled').contains('POST').should('be.selected');
        cy.get('label[for="triggerUrl"]').contains('URL');
        cy.get('#triggerUrl').should('be.enabled').and('be.empty');
        cy.get('label[for="actionIgnoreSSLErrors"]').contains('Ignore SSL errors');
        cy.get('#actionIgnoreSSLErrors').should('be.enabled').and('not.be.checked');
        cy.get('label[for="triggerTemplateType"]').contains('Payload type');
        cy.get('#triggerTemplateType')
          .should('be.enabled')
          .contains('Use default event format (JSON)')
          .should('be.selected');

        cy.get('#triggerInterfaceName').select('Any interface');
        cy.get('#triggerInterfaceMajor').should('not.exist');
        cy.get('#triggerPath').should('not.exist');
        cy.get('#triggerOperator').should('not.exist');

        cy.get('#triggerSimpleTriggerType').select('Device Trigger');
        cy.get('#triggerInterfaceName').should('not.exist');
        cy.get('label[for="triggerTargetSelect"]').contains('Target');
        cy.get('#triggerTargetSelect')
          .should('be.enabled')
          .contains('All devices')
          .should('be.selected');
        cy.get('#triggerCondition')
          .should('be.enabled')
          .contains('Device Connected')
          .should('be.selected');

        cy.get('#triggerTargetSelect').select('Device');
        cy.get('label[for="triggerDeviceId"]').contains('Device id');
        cy.get('#triggerDeviceId').should('be.enabled').and('be.empty');

        cy.get('#triggerTargetSelect').select('Group');
        cy.get('label[for="triggerGroupName"]').contains('Group Name');
        cy.get('#triggerGroupName').should('be.enabled').and('be.empty');

        cy.get('#triggerTemplateType').select('Mustache');
        cy.get('label[for="actionPayload"]').contains('Payload');
        cy.get('#actionPayload').should('be.enabled').and('be.empty');

        cy.get('#triggerActionType').select('AMQP Message');
        cy.get('label[for="amqpExchange"]').contains('Exchange');
        cy.get('#amqpExchange')
          .should('be.enabled')
          .and('be.empty')
          .and('have.attr', 'placeholder', `astarte_events_${this.realm.name}_<exchange-name>`);
        cy.get('label[for="amqpRoutingKey"]').contains('Routing key');
        cy.get('#amqpRoutingKey').should('be.enabled').and('be.empty');
        cy.get('label[for="amqpPersistency"]').contains('Persistency');
        cy.get('label[for="amqpPersistency"]').contains('Publish persistent messages');
        cy.get('#amqpPersistency').should('be.enabled').and('not.be.checked');
        cy.get('label[for="amqpPriority"]').contains('Priority');
        cy.get('#amqpPriority')
          .should('be.enabled')
          .and('have.value', '0')
          .and('have.attr', 'min', 0)
          .and('have.attr', 'max', 9);
        cy.get('label[for="amqpExpiration"]').contains('Expiration');
        cy.get('#amqpExpiration').should('be.enabled').and('have.value', '0');
      });

      it('correctly lists Trigger Type options', () => {
        cy.get('#triggerSimpleTriggerType option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['Device Trigger', 'Data Trigger']);
        });
      });

      it('correctly lists Trigger Target options for a Data trigger', () => {
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerTargetSelect option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['All devices', 'Device', 'Group']);
        });
      });

      it('correctly lists Trigger Target options for a Device trigger', () => {
        cy.get('#triggerSimpleTriggerType').select('Device Trigger');
        cy.get('#triggerTargetSelect option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['All devices', 'Device', 'Group']);
        });
      });

      it('correctly lists Trigger Condition options for a Device trigger', () => {
        cy.get('#triggerSimpleTriggerType').select('Device Trigger');
        cy.get('#triggerCondition option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq([
            'Device Connected',
            'Device Disconnected',
            'Device Error',
            'Empty Cache Received',
          ]);
        });
      });

      it('correctly lists Trigger Condition options for a Data trigger / Any interface', () => {
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select('Any interface');
        cy.get('#triggerCondition option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['Incoming Data', 'Value Stored']);
        });
      });

      it('correctly lists Trigger Condition options for a Data trigger / Datastream interface', function () {
        const iface = this.datastream_object_interface.data;
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select(iface.interface_name);
        cy.get('#triggerCondition option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['Incoming Data', 'Value Stored']);
        });
      });

      it('correctly lists Trigger Condition options for a Data trigger / Properties interface', function () {
        const iface = this.properties_interface.data;
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select(iface.interface_name);
        cy.get('#triggerCondition option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq([
            'Incoming Data',
            'Value Change',
            'Value Change Applied',
            'Path Created',
            'Path Removed',
            'Value Stored',
          ]);
        });
      });

      it('lists all available interfaces for a Data trigger', function () {
        const ifaces = this.interfaces.data;
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['Any interface', ...ifaces]);
        });
      });

      it('lists appropriate Condition Operators for the specified interface path', function () {
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select('Any interface');
        cy.get('#triggerOperator').should('not.exist');

        // Without specified path
        const iface = this.properties_interface.data;
        cy.get('#triggerInterfaceName').select(iface.interface_name);
        cy.get('#triggerPath').clear().paste('/*');
        cy.get('#triggerOperator option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['*']);
        });

        // Path with boolean value
        cy.get('#triggerPath').clear().paste('/lights/kitchen');
        cy.get('#triggerOperator option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['*', '==', '!=', '>', '>=', '<', '<=']);
        });

        // Path with array-like value (e.g. booleanarray)
        cy.get('#triggerPath').clear().paste('/lights/bath');
        cy.get('#triggerOperator option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq([
            '*',
            '==',
            '!=',
            '>',
            '>=',
            '<',
            '<=',
            'Contains',
            'Not Contains',
          ]);
        });
      });

      it('correctly lists Action Type options', () => {
        cy.get('#triggerActionType option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['HTTP request', 'AMQP Message']);
        });
      });

      it('correctly lists Method options for a HTTP action', () => {
        cy.get('#triggerActionType').select('HTTP request');
        cy.get('#triggerMethod option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PATCH', 'POST', 'PUT']);
        });
      });

      it('correctly lists Template Type options for a HTTP action', () => {
        cy.get('#triggerActionType').select('HTTP request');
        cy.get('#triggerTemplateType option').should((options) => {
          const labels = [...options].map((option) => option.textContent);
          expect(labels).to.deep.eq(['Use default event format (JSON)', 'Mustache']);
        });
      });

      it('shows Path field as invalid if not existent in its interface', function () {
        const iface = this.properties_interface.data;
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select(iface.interface_name);
        cy.get('#triggerInterfaceMajor').select(String(iface.version_major));
        cy.get('#triggerPath').clear().paste('/*');
        cy.get('#triggerPath').should('not.have.class', 'is-invalid');
        cy.get('#triggerPath').clear().paste('/invalid'); // invalid path
        cy.get('#triggerPath').should('have.class', 'is-invalid');
        cy.get('#triggerPath').clear().paste('/lights/kitchen'); // valid path
        cy.get('#triggerPath').should('not.have.class', 'is-invalid');
        cy.get('#triggerPath').clear().paste('/kitchen/heating/active'); // valid parametrized path
        cy.get('#triggerPath').should('not.have.class', 'is-invalid');
      });

      it("shows Value field as invalid if inconsistent with its path's value type", function () {
        const iface = this.properties_interface.data;
        cy.get('#triggerSimpleTriggerType').select('Data Trigger');
        cy.get('#triggerInterfaceName').select(iface.interface_name);
        cy.get('#triggerInterfaceMajor').select(String(iface.version_major));
        cy.get('#triggerPath').clear().paste('/lights/kitchen'); // boolean type
        cy.get('#triggerOperator').select('==');
        cy.get('#triggerKnownValue').clear().paste('notboolean'); // invalid boolean
        cy.get('#triggerKnownValue').should('have.class', 'is-invalid');
        cy.get('#triggerKnownValue').clear().paste('false'); // valid boolean
        cy.get('#triggerKnownValue').should('not.have.class', 'is-invalid');
      });

      it('shows amqp_exchange as invalid if it does not follow astarte_events_<realm-name>_<any-allowed-string> format', function () {
        cy.get('#triggerActionType').select('AMQP Message');
        cy.get('#amqpExchange').clear().paste('invalid_format_exchange');
        cy.get('#amqpExchange').should('have.class', 'is-invalid');
        cy.get('#amqpExchange').clear().paste(`astarte_events_${this.realm.name}_exchange`);
        cy.get('#amqpExchange').should('not.have.class', 'is-invalid');
      });

      it('shows amqp_routing_key as invalid if it contains { or }', () => {
        cy.get('#triggerActionType').select('AMQP Message');
        cy.get('#amqpRoutingKey').clear().paste('invalid_{route}');
        cy.get('#amqpRoutingKey').should('have.class', 'is-invalid');
        cy.get('#amqpRoutingKey').clear().paste('valid_route');
        cy.get('#amqpRoutingKey').should('not.have.class', 'is-invalid');
      });

      it('can add, edit, remove HTTP headers', () => {
        cy.get('#triggerActionType').select('HTTP request');

        // Add http header
        cy.contains('Add custom HTTP headers').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add Custom HTTP Header');
          cy.get('label').contains('Header');
          cy.get('#root_key').should('be.enabled').and('be.empty');
          cy.get('label').contains('Value');
          cy.get('#root_value').should('be.enabled').and('be.empty');
          cy.get('#root_key').paste('X-Custom-Header');
          cy.get('#root_value').paste('Header value');
          cy.get('button').contains('Add').click();
        });
        cy.get('table tr').contains('X-Custom-Header');
        cy.get('table tr').contains('Header value');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.http_static_headers).to.deep.eq({
              'X-Custom-Header': 'Header value',
            });
          });

        // Edit http header
        cy.get('table tr').contains('X-Custom-Header').parents('tr').get('i.fa-pencil-alt').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Edit Value for Header "X-Custom-Header"');
          cy.get('label').contains('Value');
          cy.get('#root_value').should('be.enabled').and('be.empty');
          cy.get('#root_value').paste('Header new value');
          cy.get('button').contains('Update').click();
        });
        cy.get('table tr').contains('Header new value');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.http_static_headers).to.deep.eq({
              'X-Custom-Header': 'Header new value',
            });
          });

        // Delete http header
        cy.get('table tr').contains('X-Custom-Header').parents('tr').get('i.fa-eraser').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Delete Header');
          cy.get('.modal-body').contains('Delete custom header "X-Custom-Header"?');
          cy.get('button').contains('Delete').click();
        });
        cy.contains('X-Custom-Header').should('not.exist');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.http_static_headers || {}).to.deep.eq({});
          });
      });

      it('can add, edit, remove AMQP headers', () => {
        cy.get('#triggerActionType').select('AMQP Message');

        // Add amqp header
        cy.contains('Add static AMQP headers').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Add Custom AMQP Header');
          cy.get('label').contains('Header');
          cy.get('#root_key').should('be.enabled').and('be.empty');
          cy.get('label').contains('Value');
          cy.get('#root_value').should('be.enabled').and('be.empty');
          cy.get('#root_key').paste('X-Custom-Header');
          cy.get('#root_value').paste('Header value');
          cy.get('button').contains('Add').click();
        });
        cy.get('table tr').contains('X-Custom-Header');
        cy.get('table tr').contains('Header value');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.amqp_static_headers).to.deep.eq({
              'X-Custom-Header': 'Header value',
            });
          });

        // Edit amqp header
        cy.get('table tr').contains('X-Custom-Header').parents('tr').get('i.fa-pencil-alt').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Edit Value for Header "X-Custom-Header"');
          cy.get('label').contains('Value');
          cy.get('#root_value').should('be.enabled').and('be.empty');
          cy.get('#root_value').paste('Header new value');
          cy.get('button').contains('Update').click();
        });
        cy.get('table tr').contains('Header new value');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.amqp_static_headers).to.deep.eq({
              'X-Custom-Header': 'Header new value',
            });
          });

        // Delete amqp header
        cy.get('table tr').contains('X-Custom-Header').parents('tr').get('i.fa-eraser').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Delete Header');
          cy.get('.modal-body').contains('Delete static header "X-Custom-Header"?');
          cy.get('button').contains('Delete').click();
        });
        cy.contains('X-Custom-Header').should('not.exist');
        cy.get('#triggerSource')
          .invoke('val')
          .should((triggerSource) => {
            const trigger = JSON.parse(triggerSource);
            expect(trigger.action.amqp_static_headers || {}).to.deep.eq({});
          });
      });

      it('correctly loads trigger from its source', () => {
        cy.fixture('test.astarte.FirstTrigger').then((trigger) => {
          setupTriggerEditorFromSource(trigger.data);
          checkTriggerEditorUIValues(trigger.data);
        });
      });

      it('correctly installs a trigger and redirects to list of triggers', () => {
        cy.fixture('test.astarte.FirstTrigger').then((trigger) => {
          cy.intercept('POST', '/realmmanagement/v1/*/triggers', {
            statusCode: 201,
            body: trigger,
          }).as('installTriggerRequest');
          setupTriggerEditorFromSource(trigger.data);
          cy.get('button').contains('Install Trigger').scrollIntoView().click();
          cy.wait('@installTriggerRequest')
            .its('request.body.data')
            .should('deep.eq', trigger.data);
          cy.location('pathname').should('eq', '/triggers');
          cy.get('h2').contains('Triggers');
        });
      });
    });

    context('edit trigger page', () => {
      beforeEach(() => {
        cy.fixture('test.astarte.FirstInterface').as('interface_source');
        cy.fixture('test.astarte.FirstTrigger').as('test_trigger');
        cy.intercept('GET', '/realmmanagement/v1/*/interfaces/*/*', {
          fixture: 'test.astarte.FirstInterface',
        });
        cy.intercept('GET', '/realmmanagement/v1/*/triggers/*', {
          fixture: 'test.astarte.FirstTrigger',
        });
      });

      it('correctly shows trigger data in the Editor UI', function () {
        const encodedTriggerName = encodeURIComponent(this.test_trigger.data.name);
        cy.visit(`/triggers/${encodedTriggerName}/edit`);
        cy.wait(1000);
        cy.location('pathname').should('eq', `/triggers/${encodedTriggerName}/edit`);
        checkTriggerEditorUIValues(this.test_trigger.data);
      });

      it('correctly displays all fields as readonly/disabled', function () {
        const encodedTriggerName = encodeURIComponent(this.test_trigger.data.name);
        cy.visit(`/triggers/${encodedTriggerName}/edit`);
        cy.wait(1000);
        cy.location('pathname').should('eq', `/triggers/${encodedTriggerName}/edit`);
        checkTriggerEditorUIDisabledOptions(this.test_trigger.data);
      });

      it('redirects to list of triggers after deleting a trigger', function () {
        const encodedTriggerName = encodeURIComponent(this.test_trigger.data.name);
        cy.intercept('DELETE', `/realmmanagement/v1/*/triggers/${encodedTriggerName}`, {
          statusCode: 204,
          body: '',
        }).as('deleteTriggerRequest');
        cy.visit(`/triggers/${this.test_trigger.data.name}/edit`);
        cy.wait(1000);
        cy.get('button').contains('Delete trigger').click();
        cy.get('.modal.show').within(() => {
          cy.get('.modal-header').contains('Confirmation Required');
          cy.get('.modal-body').contains(
            `You are going to delete ${this.test_trigger.data.name}. This might cause data loss, deleted triggers cannot be restored. Are you sure?`,
          );
          cy.get('.modal-body').contains(`Please type ${this.test_trigger.data.name} to proceed.`);
          cy.get('#confirmTriggerName').paste(this.test_trigger.data.name);
          cy.get('button').contains('Delete').click();
        });
        cy.wait('@deleteTriggerRequest');
        cy.location('pathname').should('eq', '/triggers');
        cy.get('h2').contains('Triggers');
      });
    });
  });
});
