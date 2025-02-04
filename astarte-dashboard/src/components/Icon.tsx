/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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
import { OverlayTrigger, Tooltip } from 'react-bootstrap';

const iconToClassName = {
  add: 'fas fa-plus',
  arrowLeft: 'fas fa-chevron-left',
  blocks: 'fas fa-shapes',
  copyPaste: 'fas fa-paste',
  delete: 'fas fa-times',
  devices: 'fas fa-cube',
  documentation: 'fa fa-book',
  edit: 'fas fa-pencil-alt',
  erase: 'fas fa-eraser',
  filter: 'fas fa-filter',
  flows: 'fas fa-wind',
  groups: 'fas fa-object-group',
  home: 'fas fa-home',
  interfaces: 'fas fa-stream',
  logout: 'fas fa-sign-out-alt',
  pipelines: 'fas fa-code-branch',
  settings: 'fas fa-cog',
  statusOK: 'fas fa-check-circle color-green',
  statusConnected: 'fas fa-circle color-green',
  statusDisconnected: 'fas fa-circle color-red',
  statusExWarning: 'fas fa-exclamation-circle color-yellow',
  statusWarning: 'fas fa-circle color-yellow',
  statusKO: 'fas fa-times-circle color-red',
  statusNeverConnected: 'fas fa-circle color-grey',
  statusInDeletion: 'fas fa-circle color-grey',
  triggers: 'fas fa-bolt',
  policy: 'fas fa-file-invoice',
};

type Icon = keyof typeof iconToClassName;

const dangerIcons: Icon[] = ['delete', 'erase'];

interface Props {
  as?: 'default' | 'button';
  className?: string;
  icon: Icon;
  onClick?: (event: React.MouseEvent<HTMLElement, MouseEvent>) => void;
  style?: React.CSSProperties;
  tooltip?: string;
  tooltipPlacement?: React.ComponentProps<typeof OverlayTrigger>['placement'];
}

export default ({
  as = 'default',
  className,
  icon,
  onClick,
  style = {},
  tooltip,
  tooltipPlacement,
}: Props): React.ReactElement => {
  const iconStyle = { ...style };
  const iconClassNames: string[] = [];
  iconClassNames.push(iconToClassName[icon]);

  if (onClick) {
    iconStyle.cursor = 'pointer';
  }
  if (as === 'button') {
    iconClassNames.push('btn');
  }
  if (dangerIcons.includes(icon)) {
    if (iconClassNames.includes('btn')) {
      iconClassNames.push('btn-danger');
    } else {
      iconClassNames.push('color-red');
    }
  }
  if (className) {
    iconClassNames.push(className);
  }

  const iconElement = (
    <i className={iconClassNames.join(' ')} style={iconStyle} onClick={onClick} />
  );

  return tooltip ? (
    <OverlayTrigger
      delay={{ show: 150, hide: 400 }}
      overlay={<Tooltip id="tooltip">{tooltip}</Tooltip>}
      placement={tooltipPlacement}
    >
      {iconElement}
    </OverlayTrigger>
  ) : (
    iconElement
  );
};
