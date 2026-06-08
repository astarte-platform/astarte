import { byteArrayToUrlSafeBase64, urlSafeBase64ToByteArray } from './Base64';

/*
  const uuid = "a717f8d6-5952-4064-add0-008d780879a9";
  const bytes = uuid.replace(/-/g, '').match(/.{2}/g).map((b) => parseInt(b, 16));
*/
const UUID_TO_BYTES = [167, 23, 248, 214, 89, 82, 64, 100, 173, 208, 0, 141, 120, 8, 121, 169];
const DEVICE_ID = 'pxf41llSQGSt0ACNeAh5qQ';

describe('Unit Test Base64 utility scripts', () => {
  it('uuid to device id', () => {
    expect(byteArrayToUrlSafeBase64(UUID_TO_BYTES)).toBe(DEVICE_ID);
  });

  it('is valid uuid', () => {
    const byteArray = urlSafeBase64ToByteArray(DEVICE_ID);

    const isValidDeviceId = byteArray.length === 17 && byteArray[16] === 0;
    expect(isValidDeviceId).toBe(true);

    for (let i = 0; i < 16; i += 1) {
      expect(byteArray[i]).toBe(UUID_TO_BYTES[i]);
    }
  });
});
