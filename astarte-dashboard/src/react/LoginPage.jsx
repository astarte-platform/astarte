/*
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import React, { useState } from 'react';
import { Button, Col, Container, Form, Row } from 'react-bootstrap';
import { AstarteRealm, AstarteToken } from 'astarte-client';

function isValidUrl(urlString) {
  try {
    // eslint-disable-next-line no-new
    new URL(urlString);
    return true;
  } catch (error) {
    return false;
  }
}

function tokenValidationFeedback(tokenValidation) {
  let message = null;

  switch (tokenValidation) {
    case 'expired':
      message = 'Provided token has expired.';
      break;

    case 'notAnAstarteToken':
      message = 'Provided JWT token has no usable Astarte claims.';
      break;

    case 'invalid':
      message = 'Invalid JWT token.';
      break;

    default:
      return null;
  }

  return <Form.Control.Feedback type="invalid">{message}</Form.Control.Feedback>;
}

const TokenForm = ({ allowSwitching, defaultRealm, onSwitchLogin, onLogin }) => {
  const [realm, setRealm] = useState(defaultRealm);
  const [token, setToken] = useState('');
  const isValidRealm = AstarteRealm.isValidName(realm);
  const tokenValidation = AstarteToken.validate(token);

  const handleTokenLogin = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const searchParams = new URLSearchParams({ realm });
    const hashParams = new URLSearchParams({ access_token: token });

    onLogin(`/auth?${searchParams}#${hashParams}`);
  };

  const AstartectlLink = () => (
    <a
      href="https://github.com/astarte-platform/astartectl#installation"
      target="_blank"
      rel="noreferrer"
    >
      astartectl
    </a>
  );

  return (
    <Form className="login-form p-3 w-100" onSubmit={handleTokenLogin}>
      <Form.Group controlId="astarteRealm">
        <Form.Label>Realm</Form.Label>
        <Form.Control
          type="text"
          placeholder="Astarte Realm"
          value={realm}
          onChange={(e) => {
            setRealm(e.target.value);
          }}
          isValid={realm !== '' && isValidRealm}
          isInvalid={realm !== '' && !isValidRealm}
          required
        />
      </Form.Group>
      <Form.Group controlId="astarteToken">
        <Form.Label>Token</Form.Label>
        <Form.Control
          as="textarea"
          rows={6}
          placeholder="Auth token"
          value={token}
          onChange={(e) => {
            setToken(e.target.value.trim());
          }}
          isValid={token !== '' && tokenValidation === 'valid'}
          isInvalid={token !== '' && tokenValidation !== 'valid'}
          required
        />
        {tokenValidationFeedback(tokenValidation)}
      </Form.Group>
      <Button
        type="submit"
        variant="primary"
        disabled={!isValidRealm || tokenValidation !== 'valid'}
        className="w-100"
      >
        Login
      </Button>
      {allowSwitching && (
        <div className="d-flex flex-row-reverse mt-2">
          <Button variant="link" onClick={() => onSwitchLogin('oauth')}>
            Switch to OAuth login
          </Button>
        </div>
      )}
      <div className="container-fluid border rounded p-2 bg-light mt-3">
        A valid JWT token should be used, you can use <AstartectlLink /> to generate one:
        <br />
        <code>$ astartectl utils gen-jwt all-realm-apis -k your_key.pem</code>
      </div>
    </Form>
  );
};

const OAuthForm = ({ allowSwitching, onSwitchLogin, defaultRealm, onLogin }) => {
  const [realm, setRealm] = useState(defaultRealm);
  const [providerUrl, setProviderUrl] = useState('');
  const isValidRealm = AstarteRealm.isValidName(realm);
  const isValidProviderUrl = isValidUrl(providerUrl);

  const oauthLogin = (event) => {
    event.preventDefault();
    event.stopPropagation();

    const dashboardLoginUrl = new URL('auth', window.location);
    dashboardLoginUrl.search = new URLSearchParams({
      realm,
      authUrl: providerUrl,
    });

    const oauthLoginUrl = new URL(providerUrl);
    oauthLoginUrl.search = new URLSearchParams({
      client_id: 'astarte-dashboard',
      response_type: 'token',
      redirect_uri: dashboardLoginUrl,
    });

    onLogin(oauthLoginUrl.toString());
  };

  return (
    <Form className="login-form p-3 w-100" onSubmit={oauthLogin}>
      <Form.Group controlId="astarteRealm">
        <Form.Label>Realm</Form.Label>
        <Form.Control
          type="text"
          placeholder="Astarte Realm"
          value={realm}
          onChange={(e) => {
            setRealm(e.target.value);
          }}
          isValid={realm !== '' && isValidRealm}
          isInvalid={realm !== '' && !isValidRealm}
          required
        />
      </Form.Group>
      <Form.Group controlId="oauthProviderUrl">
        <Form.Label>OAuth provider URL</Form.Label>
        <Form.Control
          type="text"
          placeholder="Astarte Realm"
          value={providerUrl}
          onChange={(e) => {
            setProviderUrl(e.target.value);
          }}
          isValid={providerUrl !== '' && isValidProviderUrl}
          isInvalid={providerUrl !== '' && !isValidProviderUrl}
          required
        />
      </Form.Group>
      <Button
        type="submit"
        variant="primary"
        disabled={!isValidRealm || !isValidProviderUrl}
        className="w-100"
      >
        Login
      </Button>
      {allowSwitching && (
        <div className="d-flex flex-row-reverse mt-2">
          <Button variant="link" onClick={() => onSwitchLogin('token')}>
            Switch to token login
          </Button>
        </div>
      )}
    </Form>
  );
};

const LeftColumn = () => (
  <Col lg={6} sm={false} className="p-0 no-gutters">
    <div className="d-flex flex-column align-items-center justify-content-center position-relative login-image-container">
      <img
        src="/static/img/background-login-top.svg"
        alt="Background visual spacer"
        className="w-100 position-absolute top-background-image"
      />
      <img
        src="/static/img/background-login-bottom.svg"
        alt="Background visual spacer"
        className="w-100 position-absolute bottom-background-image"
      />
      <img src="/static/img/logo-login.svg" alt="Astarte logo" className="logo m-4" />
      <img
        src="/static/img/mascotte-computer.svg"
        alt="Astarte mascotte"
        className="mascotte m-4"
      />
    </div>
  </Col>
);

const RightColumn = ({ allowSwitching, defaultRealm, type, onLogin }) => {
  const [loginType, setLoginType] = useState(type);
  const handleLoginSwitch = (value) => {
    setLoginType(value);
  };

  return (
    <Col
      lg={6}
      sm={12}
      className="bg-white d-flex flex-column align-items-center justify-content-center"
    >
      <h1>Sign In</h1>
      {loginType === 'oauth' ? (
        <OAuthForm
          defaultRealm={defaultRealm}
          allowSwitching={allowSwitching}
          onSwitchLogin={handleLoginSwitch}
          onLogin={onLogin}
        />
      ) : (
        <TokenForm
          defaultRealm={defaultRealm}
          allowSwitching={allowSwitching}
          onSwitchLogin={handleLoginSwitch}
          onLogin={onLogin}
        />
      )}
    </Col>
  );
};

export default ({ history, type, allowSwitching, defaultRealm }) => (
  <Container fluid>
    <Row>
      <LeftColumn />
      <RightColumn
        type={type}
        allowSwitching={allowSwitching}
        defaultRealm={defaultRealm}
        onLogin={(url) => history.push(url)}
      />
    </Row>
  </Container>
);
