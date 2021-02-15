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

import React from 'react';
import { Container } from 'react-bootstrap';
import BackButton from './BackButton';

interface Props {
  backLink?: string;
  children: React.ReactNode;
  docsLink?: string;
  title: string;
}

export default function SingleCardPage({
  backLink,
  children,
  docsLink,
  title,
}: Props): React.ReactElement {
  return (
    <Container fluid className="p-3">
      <header className="d-flex justify-content-between align-items-baseline">
        <h2>
          {backLink && <BackButton href={backLink} />}
          {title}
        </h2>
        {docsLink && (
          <div className="float-right">
            <a target="_blank" rel="noreferrer" href={docsLink}>
              <i className="fa fa-book mr-2" />
              Documentation
            </a>
          </div>
        )}
      </header>
      <Container fluid className="bg-white rounded p-3">
        {children}
      </Container>
    </Container>
  );
}
