/*
   This file is part of Astarte.

   Copyright 2020-2024 SECO Mind Srl

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

import { describe, it, expect } from 'vitest';
import type { RJSFSchema } from '@rjsf/utils';
import validator from './EvalFreeValidator';

// From RegisterDevicePage NamespaceModal
const uuidSchema: RJSFSchema = {
  type: 'object',
  required: ['userNamespace'],
  properties: {
    userNamespace: {
      title: 'Namespace UUID',
      type: 'string',
      pattern: '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    },
    userString: { title: 'Name', type: 'string' },
  },
};

// From DeviceStatusPage/NewAttributeModal
const attributeSchema: RJSFSchema = {
  type: 'object',
  required: ['key', 'value'],
  properties: {
    key: { title: 'Key', type: 'string' },
    value: { title: 'Value', type: 'string' },
  },
};

// From a bundled Astarte Flow block (http_source) — JSON Schema draft-04
const httpSourceSchema: RJSFSchema = {
  $id: 'https://astarte-platform.org/specs/astarte_flow/blocks/http_source.json',
  $schema: 'http://json-schema.org/draft-04/schema#',
  additionalProperties: false,
  type: 'object',
  required: ['base_url', 'target_paths', 'polling_interval_ms'],
  properties: {
    base_url: { type: 'string' },
    headers: { additionalProperties: { type: 'string' }, type: 'object' },
    polling_interval_ms: { type: 'integer' },
    target_paths: { items: { type: 'string' }, type: 'array' },
  },
};

// Schema with $ref / definitions, representative of virtual_device_pool block
const refSchema: RJSFSchema = {
  $schema: 'http://json-schema.org/draft-04/schema#',
  type: 'object',
  required: ['items'],
  properties: {
    items: {
      type: 'array',
      items: { $ref: '#/definitions/entry' },
    },
  },
  definitions: {
    entry: {
      type: 'object',
      required: ['name'],
      properties: { name: { type: 'string' } },
    },
  },
};

// isValid

describe('isValid', () => {
  it('returns true for valid data', () => {
    expect(validator.isValid(attributeSchema, { key: 'k', value: 'v' }, attributeSchema)).toBe(
      true,
    );
  });

  it('returns false when a required field is missing', () => {
    expect(validator.isValid(attributeSchema, { key: 'k' }, attributeSchema)).toBe(false);
  });

  it('returns false when a pattern does not match', () => {
    expect(validator.isValid(uuidSchema, { userNamespace: 'not-a-uuid' }, uuidSchema)).toBe(false);
  });

  it('returns true when a pattern matches', () => {
    expect(
      validator.isValid(
        uuidSchema,
        { userNamespace: '753ffc99-dd9d-4a08-a07e-9b0d6ce0bc82' },
        uuidSchema,
      ),
    ).toBe(true);
  });

  it('handles block schema (draft-04, additionalProperties)', () => {
    expect(
      validator.isValid(
        httpSourceSchema,
        { base_url: 'http://a', target_paths: ['/'], polling_interval_ms: 1000 },
        httpSourceSchema,
      ),
    ).toBe(true);
  });

  it('rejects extra properties when additionalProperties is false', () => {
    expect(
      validator.isValid(
        httpSourceSchema,
        {
          base_url: 'http://a',
          target_paths: ['/'],
          polling_interval_ms: 1000,
          unexpected_field: true,
        },
        httpSourceSchema,
      ),
    ).toBe(false);
  });

  it('handles schemas with $ref and definitions', () => {
    expect(validator.isValid(refSchema, { items: [{ name: 'device-1' }] }, refSchema)).toBe(true);
    expect(validator.isValid(refSchema, { items: [{ notName: 'x' }] }, refSchema)).toBe(false);
  });
});

// validateFormData

describe('validateFormData', () => {
  it('returns no errors for valid data', () => {
    const { errors } = validator.validateFormData({ key: 'k', value: 'v' }, attributeSchema);
    expect(errors).toHaveLength(0);
  });

  it('reports missing required fields', () => {
    const { errors, errorSchema } = validator.validateFormData({ key: 'k' }, attributeSchema);
    expect(errors.length).toBeGreaterThan(0);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect((errorSchema as any)?.value?.__errors?.length).toBeGreaterThan(0);
  });

  it('reports pattern violation with the correct property path', () => {
    const { errors } = validator.validateFormData({ userNamespace: 'bad' }, uuidSchema);
    const patternError = errors.find((e) => e.name === 'pattern');
    expect(patternError).toBeDefined();
    expect(patternError?.property).toMatch(/userNamespace/);
  });

  it('routes pattern error into errorSchema at the correct field key', () => {
    // rjsf reads errorSchema (not the flat errors array) to pass rawErrors to
    // each field widget.  A wrong property path silently populates the wrong
    // key, leaving the field label unhighlighted despite a validation failure.
    const { errorSchema } = validator.validateFormData({ userNamespace: 'not-a-uuid' }, uuidSchema);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect((errorSchema as any)?.userNamespace?.__errors?.length).toBeGreaterThan(0);
    expect(errorSchema?.__errors ?? []).toHaveLength(0);
  });

  it('routes error to root (".") when the property path is empty (root-level type mismatch)', () => {
    // Stripping "instance" from a root-level error path leaves "", which must
    // become ".", an empty string causes toErrorSchema to silently drop it.
    const stringSchema: RJSFSchema = { type: 'string' };
    const { errors } = validator.validateFormData({} as unknown as string, stringSchema);
    expect(errors.length).toBeGreaterThan(0);
    errors.forEach((e) => expect(e.property).toBeTruthy());
  });

  it('applies transformErrors callback', () => {
    const { errors } = validator.validateFormData(
      { userNamespace: 'bad' },
      uuidSchema,
      undefined,
      (errs) =>
        errs.map((e) =>
          e.name === 'pattern' ? { ...e, message: 'The namespace must be a valid UUID' } : e,
        ),
    );
    const patternError = errors.find((e) => e.name === 'pattern');
    expect(patternError?.message).toBe('The namespace must be a valid UUID');
  });

  it('applies customValidate callback', () => {
    const { errors, errorSchema } = validator.validateFormData(
      { key: 'reserved', value: 'v' },
      attributeSchema,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (formData: any, err: any) => {
        if (formData?.key === 'reserved') {
          err.key?.addError('"reserved" is not allowed as a key');
        }
        return err;
      },
    );
    expect(errors.some((e) => e.message?.includes('reserved'))).toBe(true);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect((errorSchema as any)?.key?.__errors).toContain('"reserved" is not allowed as a key');
  });

  it('handles block schema (draft-04) correctly', () => {
    const { errors } = validator.validateFormData(
      { base_url: 'http://a', target_paths: ['/'], polling_interval_ms: 100 },
      httpSourceSchema,
    );
    expect(errors).toHaveLength(0);
  });
});

// rawValidation

describe('rawValidation', () => {
  it('returns empty errors for valid data', () => {
    const { errors, validationError } = validator.rawValidation(attributeSchema, {
      key: 'k',
      value: 'v',
    });
    expect(validationError).toBeUndefined();
    expect(errors).toHaveLength(0);
  });

  it('returns errors for invalid data', () => {
    const { errors } = validator.rawValidation(attributeSchema, { key: 'k' });
    expect(errors?.length).toBeGreaterThan(0);
  });

  it('does not throw for an unresolvable $ref', () => {
    const brokenSchema = { $ref: '#/definitions/nonexistent' };
    const result = validator.rawValidation(brokenSchema, {});
    expect(result).toBeDefined();
  });
});
