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

const charset = (() => {
  const newCharset = [];
  let baseCode;
  let i;

  baseCode = 'A'.charCodeAt(0);
  for (i = 0; i < 26; i += 1) {
    newCharset.push(String.fromCharCode(baseCode + i));
  }

  baseCode = 'a'.charCodeAt(0);
  for (i = 0; i < 26; i += 1) {
    newCharset.push(String.fromCharCode(baseCode + i));
  }

  baseCode = '0'.charCodeAt(0);
  for (i = 0; i < 10; i += 1) {
    newCharset.push(String.fromCharCode(baseCode + i));
  }

  newCharset.push('-');
  newCharset.push('_');

  return newCharset;
})();

export function byteArrayToUrlSafeBase64(bytes: number[]): string {
  const binaryArray = bytes.map((b) => b.toString(2));

  const padding = '0'.padEnd(6 - ((bytes.length * 8) % 6), '0');
  const binaryString = binaryArray.map((b) => b.padStart(8, '0')).join('') + padding;
  const octects = binaryString.match(/.{6}/g) || [];

  return octects.map((b) => charset[parseInt(b, 2)]).join('');
}

export function urlSafeBase64ToByteArray(base64string: string): number[] {
  let binaryString = '';
  for (let i = 0; i < base64string.length; i += 1) {
    binaryString += charset.indexOf(base64string[i]).toString(2).padStart(6, '0');
  }

  const octects = binaryString.match(/.{1,8}/g);
  if (octects) {
    return octects.map((b) => parseInt(b, 2));
  }
  return [];
}
