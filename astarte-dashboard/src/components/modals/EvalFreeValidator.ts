import { Validator } from '@cfworker/json-schema';
import {
  createErrorHandler,
  getDefaultFormState,
  toErrorList,
  toErrorSchema,
  unwrapErrorHandler,
  validationDataMerge,
} from '@rjsf/utils';
import type {
  CustomValidator,
  ErrorSchema,
  ErrorTransformer,
  FormContextType,
  RJSFSchema,
  RJSFValidationError,
  StrictRJSFSchema,
  UiSchema,
  ValidatorType,
} from '@rjsf/utils';

function toRJSFValidationErrors(errors: any[]): RJSFValidationError[] {
  // @cfworker/json-schema emits cascade-summary errors (keyword "properties" /
  // "items") at parent instance locations in addition to the real leaf errors.
  // These serve no purpose for RJSF field highlighting and would populate
  // errorSchema.__errors, so they can be dropped
  const leafErrors = errors.filter((e) => e.keyword !== 'properties' && e.keyword !== 'items');
  return leafErrors.map((e) => {
    // @cfworker/json-schema uses JSON Pointer instance locations (#, #/foo, #/foo/bar).
    // The leading '#' is stripped here before converting '/' separators to '.' so that
    // toErrorSchema can correctly map each error to its field key.
    let property = e.instanceLocation.replace(/^#/, '').replace(/\//g, '.');
    if (property.startsWith('.')) {
      property = property.substring(1);
    }

    let message = e.error;
    let name = e.keyword || 'custom';
    let params: any = {};

    if (message.includes('required')) {
      name = 'required';
      message = 'is a required property';
      const missingProp = e.error.split('"')[1];
      if (missingProp) {
        property = property ? `${property}.${missingProp}` : `.${missingProp}`;
        params = { missingProperty: missingProp };
      }
    }

    if (property && !property.startsWith('.') && !property.startsWith('[')) {
      property = `.${property}`;
    }

    const stack = property ? `${property} ${message}`.trim() : message;

    return {
      name,
      property: property || '.',
      message,
      params,
      stack,
      schemaPath: e.schemaLocation || '',
    };
  });
}

class EvalFreeValidator<
  T = unknown,
  S extends StrictRJSFSchema = RJSFSchema,
  F extends FormContextType = FormContextType,
> implements ValidatorType<T, S, F>
{
  isValid(schema: S, formData: T | undefined, rootSchema: S): boolean {
    try {
      const validator = new Validator(schema as any);
      const dataToValidate =
        formData === undefined
          ? getDefaultFormState(this, schema, formData, rootSchema, true)
          : formData;
      const result = validator.validate(dataToValidate);
      return result.valid;
    } catch {
      return false;
    }
  }

  rawValidation<Result = any>(
    schema: S,
    formData?: T,
  ): { errors?: Result[]; validationError?: Error } {
    try {
      const validator = new Validator(schema as any);
      const result = validator.validate(formData);
      return { errors: result.errors as unknown as Result[] };
    } catch (e) {
      return { validationError: e as Error };
    }
  }

  validateFormData(
    formData: T | undefined,
    schema: S,
    customValidate?: CustomValidator<T, S, F>,
    transformErrors?: ErrorTransformer<T, S, F>,
    uiSchema?: UiSchema<T, S, F>,
  ): { errors: RJSFValidationError[]; errorSchema: ErrorSchema<T> } {
    // jsonschema treats null as a non-object and produces a type error instead
    // of per-field required errors.  Normalise null → {} for object schemas so
    // that a pristine form (formData = null) yields the same field-level errors
    // that @rjsf/validator-ajv8 would produce (i.e. the is-invalid class on
    // each missing required input).
    const isObjectSchema = (schema as Record<string, unknown>)?.type === 'object';
    const normalizedData =
      (formData === null || formData === undefined) && isObjectSchema
        ? ({} as unknown as T)
        : formData;

    const { errors: rawErrors = [], validationError } = this.rawValidation<any>(
      schema,
      normalizedData,
    );

    let errors = toRJSFValidationErrors(rawErrors);

    if (validationError) {
      errors = [...errors, { stack: validationError.message } as RJSFValidationError];
    }

    if (typeof transformErrors === 'function') {
      errors = transformErrors(errors, uiSchema);
    }

    let errorSchema = toErrorSchema(errors) as ErrorSchema<T>;

    if (validationError) {
      errorSchema = {
        ...errorSchema,
        $schema: { __errors: [validationError.message] },
      } as ErrorSchema<T>;
    }

    if (typeof customValidate !== 'function') {
      return { errors, errorSchema };
    }

    const newFormData = (normalizedData ?? ({} as unknown as T)) as T;
    const errorHandler = customValidate(newFormData, createErrorHandler<T>(newFormData), uiSchema);
    const userErrorSchema = unwrapErrorHandler(errorHandler);
    return validationDataMerge({ errors, errorSchema }, userErrorSchema);
  }

  toErrorList(errorSchema?: ErrorSchema<T>, fieldPath: string[] = []): RJSFValidationError[] {
    return toErrorList(errorSchema, fieldPath);
  }
}

const evalFreeValidator = new EvalFreeValidator();
export default evalFreeValidator;
