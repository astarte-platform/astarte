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

import React, { useCallback, useEffect, useMemo, useState } from 'react';

import { Button, Form, Modal, Spinner } from 'react-bootstrap';
import Ajv from 'ajv';

import JsonSchemaForm from '@rjsf/bootstrap-4';

import { useAlerts } from './AlertManager';
import VisualFlowEditor, { getNewModel, nodeModelToSource } from './components/VisualFlowEditor';
import SingleCardPage from './ui/SingleCardPage';

const ajv = new Ajv({ schemaId: 'id' });
const metaSchemaDraft04 = require('ajv/lib/refs/json-schema-draft-04.json');

ajv.addMetaSchema(metaSchemaDraft04);

const NodeSettingsModal = ({ node, schema, initialData, onCancel, onConfirm }) => (
  <Modal size="lg" show onHide={onCancel}>
    <Modal.Header closeButton>
      <Modal.Title>Settings for {node.name}</Modal.Title>
    </Modal.Header>
    <Modal.Body>
      <JsonSchemaForm
        schema={schema}
        additionalMetaSchemas={[metaSchemaDraft04]}
        formData={initialData}
        onSubmit={(params) => onConfirm(params.formData)}
      >
        <div className="form-footer">
          <Button type="submit" variant="primary">
            Apply settings
          </Button>
          <Button variant="secondary mr-2" onClick={onCancel}>
            Cancel
          </Button>
        </div>
      </JsonSchemaForm>
    </Modal.Body>
  </Modal>
);

const CommandRow = ({ className = '', children }) => (
  <div className={['d-flex flex-row-reverse', className].join(' ')}>{children}</div>
);

export default ({ astarte, history }) => {
  const [editorModel] = useState(getNewModel());
  const [isCreatingPipeline, setIsCreatingPipeline] = useState(false);
  const [blocks, setBlocks] = useState([]);
  const [activeModal, setActiveModal] = useState(null);
  const [pipeline, setPipeline] = useState({
    name: '',
    description: '',
    source: '',
    schema: '',
  });
  const formAlerts = useAlerts();

  useEffect(() => {
    astarte
      .getBlocks()
      .then((astarteBlocks) => {
        setBlocks(astarteBlocks);
      })
      .catch((error) => {
        formAlerts.showError(`Couldn't retrieve block descriptions: ${error.message}`);
      });
  }, [astarte]);

  const schemaObject = useMemo(() => {
    if (pipeline.schema === '') {
      return undefined;
    }
    try {
      const schema = JSON.parse(pipeline.schema);
      return schema;
    } catch (e) {
      return undefined;
    }
  }, [pipeline.schema]);

  const createPipeline = useCallback(() => {
    setIsCreatingPipeline(true);

    const pipelineParams = {
      name: pipeline.name,
      source: pipeline.source,
      description: pipeline.description,
    };

    if (schemaObject) {
      pipelineParams.schema = schemaObject;
    }

    astarte
      .registerPipeline(pipelineParams)
      .then(() => history.push('/pipelines'))
      .catch((err) => {
        setIsCreatingPipeline(false);
        formAlerts.showError(`Couldn't create pipeline: ${err.message}`);
      });
  }, [astarte, history, setIsCreatingPipeline, formAlerts.showError, pipeline, schemaObject]);

  const isValidSchema = useMemo(() => {
    if (!schemaObject) {
      return false;
    }
    try {
      ajv.compile(schemaObject);
      return true;
    } catch (e) {
      return false;
    }
  }, [schemaObject, ajv]);

  const blockSettingsClickHandler = useCallback(
    (e, node) => {
      const blockDefinition = blocks.find((block) => node.name === block.name);

      editorModel.setLocked(true);

      setActiveModal(
        <NodeSettingsModal
          node={node}
          schema={blockDefinition.schema}
          initialData={node.getProperties()}
          onCancel={() => {
            setActiveModal(null);
            editorModel.setLocked(false);
          }}
          onConfirm={(props) => {
            node.setProperties(props);
            setActiveModal(null);
            editorModel.setLocked(false);
          }}
        />,
      );
    },
    [blocks],
  );

  const sourceConversionHandler = () => {
    try {
      const pipelineSource = nodeModelToSource(editorModel);
      setPipeline({ ...pipeline, source: pipelineSource });
    } catch (error) {
      formAlerts.showError(error.message);
    }
  };

  const isValidPipelineName = pipeline.name !== '' && pipeline.name !== 'new';
  const isValidSource = pipeline.source !== '';
  const isValidForm = isValidPipelineName && isValidSource;

  return (
    <SingleCardPage title="New Pipeline" backLink="/pipelines">
      <formAlerts.Alerts />
      <Form>
        <Form.Group controlId="pipeline-name">
          <Form.Label>Name</Form.Label>
          <Form.Control
            type="text"
            value={pipeline.name}
            onChange={(e) => setPipeline({ ...pipeline, name: e.target.value })}
          />
        </Form.Group>
        {pipeline.source === '' ? (
          <>
            <Form.Group controlId="pipeline-source">
              <VisualFlowEditor
                className="mb-2"
                blocks={blocks}
                model={editorModel}
                onNodeSettingsClick={blockSettingsClickHandler}
              />
            </Form.Group>
            <CommandRow>
              <Button variant="primary" onClick={sourceConversionHandler}>
                Generate pipeline source
              </Button>
            </CommandRow>
          </>
        ) : (
          <>
            <Form.Group controlId="pipeline-source">
              <Form.Label>Source</Form.Label>
              <Form.Control
                as="textarea"
                rows={8}
                value={pipeline.source}
                onChange={(e) => setPipeline({ ...pipeline, source: e.target.value })}
              />
            </Form.Group>
            <Form.Group controlId="pipeline-schema">
              <Form.Label>Schema</Form.Label>
              <Form.Control
                as="textarea"
                rows={8}
                value={pipeline.schema}
                isValid={pipeline.schema !== '' && isValidSchema}
                isInvalid={pipeline.schema !== '' && !isValidSchema}
                onChange={(e) => setPipeline({ ...pipeline, schema: e.target.value })}
              />
            </Form.Group>
            <Form.Group controlId="pipeline-description">
              <Form.Label>Description</Form.Label>
              <Form.Control
                as="textarea"
                value={pipeline.description}
                onChange={(e) => setPipeline({ ...pipeline, description: e.target.value })}
              />
            </Form.Group>
            <CommandRow>
              <Button
                variant="primary"
                onClick={createPipeline}
                disabled={!isValidForm || isCreatingPipeline}
              >
                {isCreatingPipeline && (
                  <Spinner as="span" size="sm" animation="border" role="status" className="mr-2" />
                )}
                Create new pipeline
              </Button>
            </CommandRow>
          </>
        )}
      </Form>
      {activeModal}
    </SingleCardPage>
  );
};
