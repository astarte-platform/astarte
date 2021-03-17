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

import type { ChartData, ChartDataKind, ChartDataWrapper } from '../dataKinds';

interface DataKindConstructor<Kind extends ChartDataKind> {
  new (data: Kind): Kind;
}

class ChartProvider<Wrapper extends ChartDataWrapper, Kind extends ChartDataKind> {
  readonly name: string;

  readonly dataWrapper: Wrapper;

  readonly dataKind: DataKindConstructor<Kind>;

  private readonly $getData: () => Promise<ChartData<Wrapper, Kind> | null>;

  constructor(params: {
    name: string;
    dataWrapper: Wrapper;
    dataKind: DataKindConstructor<Kind>;
    getData: () => Promise<ChartData<Wrapper, Kind> | null>;
  }) {
    this.name = params.name;
    this.dataWrapper = params.dataWrapper;
    this.dataKind = params.dataKind;
    this.$getData = params.getData;
  }

  async getData(): Promise<ChartData<Wrapper, Kind> | null> {
    const data = await this.$getData();
    if (data == null) {
      return null;
    }
    const DataKindCtor = this.dataKind;
    switch (this.dataWrapper) {
      case 'Array':
        // @ts-expect-error cannot infer type
        return data.map((value) => new DataKindCtor(value));
      case 'Object':
      default:
        // @ts-expect-error cannot infer type
        return new DataKindCtor(data);
    }
  }
}

export { ChartProvider };
