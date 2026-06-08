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

import React from 'react';

interface Props {
  children: string;
  word?: string;
}

const Highlight = ({ children, word }: Props): React.ReactElement => {
  if (!word) {
    return <>{children}</>;
  }

  return (
    <>
      {children.split(word).map((chunk, index) => (
        <React.Fragment key={index}>
          {index !== 0 && (
            <span key={`word-${index}`} className="bg-warning text-dark">
              {word}
            </span>
          )}
          {chunk}
        </React.Fragment>
      ))}
    </>
  );
};

export default Highlight;
