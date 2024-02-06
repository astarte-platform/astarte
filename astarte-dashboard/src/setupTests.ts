import { cleanup } from '@testing-library/react';

// react requires the flag to be set in tests
// @ts-ignore
global.IS_REACT_ACT_ENVIRONMENT = true;

afterEach(() => {
  cleanup();
});
