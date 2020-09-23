#!/usr/bin/env node
const fs = require('fs');

const paramRegex = /--([a-zA-Z0-9_-]*)=(.*)/g;
const args = {};

process.argv.slice(2).forEach((arg) => {
  [...arg.matchAll(paramRegex)].forEach(([, param, value]) => {
    args[param] = value;
  });
});

const config = {
  astarte_api_url: args['astarte-api-url'] || 'https://api.example.com',
  enable_flow_preview: !!args['enable-flow'],
  default_auth: 'token',
  auth: [{ type: 'Token' }],
};

const configDir = args.url || '.';

if (!fs.existsSync(configDir)) {
  fs.mkdirSync(configDir);
}

const fileUrl = `${configDir}/config.json`;

fs.writeFile(fileUrl, JSON.stringify(config), (err) => {
  if (err) {
    process.exit(1);
  } else {
    process.exit(0);
  }
});
