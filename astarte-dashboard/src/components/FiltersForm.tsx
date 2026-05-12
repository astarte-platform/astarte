/*
   This file is part of Astarte.

   Copyright 2024 SECO Mind Srl

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

import React, { useState } from 'react';
import { Button, Form, Col, Row, Spinner } from 'react-bootstrap';
import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';

interface FiltersFormProps {
  interfacePaths: string[];
  onFiltersChange: (path: string, since?: string, to?: string) => void;
  isLoading?: boolean;
}

const FiltersForm = ({
  interfacePaths,
  onFiltersChange,
  isLoading,
}: FiltersFormProps): React.ReactElement => {
  const [fromTime, setFromTime] = useState<Date | null>(null);
  const [toTime, setToTime] = useState<Date | null>(null);
  const [path, setPath] = useState<string>('');

  const handleFetchData = () => {
    const since = fromTime ? fromTime.toISOString() : undefined;
    const to = toTime ? toTime.toISOString() : undefined;
    onFiltersChange(path, since, to);
  };

  return (
    <>
      <Row className="mb-4">
        <Col xs={12} md={2} className="d-flex justify-content-between">
          <Form.Group controlId="formPath" className="d-flex align-items-center">
            <Form.Label className="me-2 mb-0">Path</Form.Label>
            <Form.Control as="select" value={path} onChange={(e) => setPath(e.target.value)}>
              <option value="">Select path</option>
              {interfacePaths.map((pathOption) => (
                <option key={pathOption} value={pathOption}>
                  {pathOption}
                </option>
              ))}
            </Form.Control>
          </Form.Group>
        </Col>
        <Col
          xs={12}
          md={6}
          className="d-flex align-items-center justify-content-center justify-content-between"
        >
          <Form.Group controlId="formFromTime" className="d-flex align-items-center">
            <Form.Label className="me-2 mb-0">From</Form.Label>
            <DatePicker
              selected={fromTime}
              onChange={(date: Date) => setFromTime(date)}
              showTimeSelect
              dateFormat="Pp"
              className="form-control"
              placeholderText="Select from time"
            />
          </Form.Group>
          <Form.Group controlId="formToTime" className="d-flex align-items-center">
            <Form.Label className="me-2 mb-0">To</Form.Label>
            <DatePicker
              selected={toTime}
              onChange={(date: Date) => setToTime(date)}
              showTimeSelect
              dateFormat="Pp"
              className="form-control"
              placeholderText="Select to time"
            />
          </Form.Group>
          <Button variant="primary" onClick={handleFetchData} disabled={isLoading}>
            {isLoading ? <Spinner size="sm" animation="border" /> : 'Filter Data'}
          </Button>
        </Col>
      </Row>
    </>
  );
};

export default FiltersForm;
