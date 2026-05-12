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

import { configureStore } from '@reduxjs/toolkit';
import { useDispatch, useSelector, Selector } from 'react-redux';
import type AstarteClient from 'astarte-client';
import _ from 'lodash';

import actions from './actions';
import selectors from './selectors';
import storeSlices, { StoreState } from './slices';

const reducer = _.mapValues(storeSlices, (slice) => slice.reducer);

// eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
const createStore = (astarte: AstarteClient) =>
  configureStore({
    reducer,
    middleware: (getDefaultMiddleware) =>
      getDefaultMiddleware({
        serializableCheck: {
          ignoredActionPaths: ['payload'],
          ignoredPaths: Object.keys(reducer),
        },
        thunk: {
          extraArgument: astarte,
        },
      }),
  });

type Store = ReturnType<typeof createStore>;
type StoreDispatch = Store['dispatch'];
type StoreSelector<SelectedState, OwnProps = null> = Selector<StoreState, SelectedState, OwnProps>;

const useStoreDispatch = (): StoreDispatch => useDispatch<StoreDispatch>();

const useStoreSelector = <SelectedState>(
  getSelector: (s: typeof selectors) => StoreSelector<SelectedState>,
): SelectedState => useSelector<StoreState, SelectedState>(getSelector(selectors));

export { actions, useStoreDispatch, useStoreSelector };

export default createStore;
