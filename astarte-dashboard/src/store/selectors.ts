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

import type { StoreState } from './slices';

const selectors = {
  blocks: () => (state: StoreState) => state.blocks.blocks,
  block: (name: string) => (state: StoreState) =>
    state.blocks.blocks.find((block) => block.name === name) || null,
  blocksError: () => (state: StoreState) => state.blocks.error || null,
  blockError: (name: string) => (state: StoreState) => state.blocks.errorByBlock[name] || null,
  blocksStatus: () => (state: StoreState) => state.blocks.status,
  blockStatus: (name: string) => (state: StoreState) => {
    if (
      selectors.isRegisteringBlock(name)(state) ||
      selectors.isUpdatingBlock(name)(state) ||
      selectors.isDeletingBlock(name)(state)
    ) {
      return 'loading';
    }
    if (selectors.blockError(name)(state)) {
      return 'err';
    }
    return 'ok';
  },
  isRegisteringBlock: (name: string) => (state: StoreState) =>
    state.blocks.blocksBeingRegistered.includes(name),
  isUpdatingBlock: (name: string) => (state: StoreState) =>
    state.blocks.blocksBeingUpdated.includes(name),
  isDeletingBlock: (name: string) => (state: StoreState) =>
    state.blocks.blocksBeingDeleted.includes(name),
} as const;

export default selectors;
