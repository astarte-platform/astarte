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

import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import AstarteClient, { AstarteBlock, AstarteCustomBlock } from 'astarte-client';
import _ from 'lodash';

interface BlocksState {
  blocks: AstarteBlock[];
  status: 'loading' | 'ok' | 'err';
  error: string | null;
  errorByBlock: { [blockName: string]: string };
  blocksBeingRegistered: string[];
  blocksBeingUpdated: string[];
  blocksBeingDeleted: string[];
}

const initialState: BlocksState = {
  blocks: [],
  status: 'ok',
  error: null,
  errorByBlock: {},
  blocksBeingRegistered: [],
  blocksBeingUpdated: [],
  blocksBeingDeleted: [],
};

const asyncActions = {
  getList: createAsyncThunk('blocks/getList', (params, { extra }) =>
    (extra as AstarteClient).getBlocks(),
  ),
  get: createAsyncThunk('blocks/get', (name: string, { extra }) =>
    (extra as AstarteClient).getBlock(name),
  ),
  register: createAsyncThunk('blocks/register', (block: AstarteCustomBlock, { extra }) =>
    (extra as AstarteClient).registerBlock(block),
  ),
  delete: createAsyncThunk('blocks/delete', (name: string, { extra }) =>
    (extra as AstarteClient).deleteBlock(name),
  ),
} as const;

const blocksSlice = createSlice({
  name: 'blocks',
  initialState,
  reducers: {},
  extraReducers: (builder) => {
    builder.addCase(asyncActions.getList.pending, (state) => {
      state.status = 'loading';
      state.blocksBeingUpdated = state.blocks.map((block) => block.name);
    });
    builder.addCase(asyncActions.getList.fulfilled, (state, action) => {
      state.blocks = action.payload;
      state.blocksBeingUpdated = [];
      state.status = 'ok';
    });
    builder.addCase(asyncActions.getList.rejected, (state, action) => {
      state.blocksBeingUpdated = [];
      state.error = action.error.message || 'Could not fetch blocks';
      state.status = 'err';
    });
    builder.addCase(asyncActions.get.pending, (state, action) => {
      const blockName = action.meta.arg;
      state.status = 'loading';
      delete state.errorByBlock[blockName];
      state.blocksBeingUpdated = _.union(state.blocksBeingUpdated, [blockName]);
    });
    builder.addCase(asyncActions.get.fulfilled, (state, action) => {
      const fetchedBlock = action.payload;
      const blockIndex = state.blocks.findIndex((block) => block.name === fetchedBlock.name);
      if (blockIndex === -1) {
        state.blocks = state.blocks.concat(fetchedBlock);
      } else {
        state.blocks[blockIndex] = fetchedBlock;
      }
      delete state.errorByBlock[fetchedBlock.name];
      state.blocksBeingUpdated = _.without(state.blocksBeingUpdated, fetchedBlock.name);
      state.status = 'ok';
    });
    builder.addCase(asyncActions.get.rejected, (state, action) => {
      const blockName = action.meta.arg;
      state.blocksBeingUpdated = _.without(state.blocksBeingUpdated, blockName);
      const error = action.error.message || 'Could not fetch blocks';
      state.errorByBlock[blockName] = error;
      state.error = error;
      state.status = 'err';
    });
    builder.addCase(asyncActions.register.pending, (state, action) => {
      const blockName = action.meta.arg.name;
      state.blocksBeingRegistered = _.union(state.blocksBeingRegistered, [blockName]);
      delete state.errorByBlock[blockName];
      state.status = 'loading';
    });
    builder.addCase(asyncActions.register.fulfilled, (state, action) => {
      const registeredBlock = action.meta.arg;
      state.blocks = state.blocks.concat(registeredBlock);
      delete state.errorByBlock[registeredBlock.name];
      state.blocksBeingRegistered = _.without(state.blocksBeingRegistered, registeredBlock.name);
      state.status = 'ok';
    });
    builder.addCase(asyncActions.register.rejected, (state, action) => {
      const blockName = action.meta.arg.name;
      state.blocksBeingRegistered = _.without(state.blocksBeingRegistered, blockName);
      const error = action.error.message || `Could not register block ${blockName}`;
      state.errorByBlock[blockName] = error;
      state.error = error;
      state.status = 'err';
    });
    builder.addCase(asyncActions.delete.pending, (state, action) => {
      const blockName = action.meta.arg;
      state.blocksBeingDeleted = _.union(state.blocksBeingDeleted, [blockName]);
      delete state.errorByBlock[blockName];
      state.status = 'loading';
    });
    builder.addCase(asyncActions.delete.fulfilled, (state, action) => {
      const blockName = action.meta.arg;
      state.blocks = state.blocks.filter((block) => block.name !== blockName);
      state.blocksBeingDeleted = _.without(state.blocksBeingDeleted, blockName);
      delete state.errorByBlock[blockName];
      state.status = 'ok';
    });
    builder.addCase(asyncActions.delete.rejected, (state, action) => {
      const blockName = action.meta.arg;
      state.blocksBeingDeleted = _.without(state.blocksBeingDeleted, blockName);
      const error = action.error.message || `Could not delete block ${blockName}`;
      state.errorByBlock[blockName] = error;
      state.error = error;
      state.status = 'err';
    });
  },
});

const actions = { ...blocksSlice.actions, ...asyncActions } as const;
const slice = { ...blocksSlice, actions } as const;

export type { BlocksState };

export default slice;
