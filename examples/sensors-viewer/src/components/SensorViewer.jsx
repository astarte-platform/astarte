import React, {Component} from 'react';
import {Images} from "../Images";
import {
  Accordion,
  Button,
  Card,
  Col,
  Container,
  Form,
  FormControl,
  InputGroup,
  ListGroup,
  Modal,
  Row
} from 'react-bootstrap'

class SensorViewer extends Component {
  state = {
    visible: true,
    sensors: [
      {
        name: "sensor 1",
        id: '1',
        period: '1 Sample Every Seconds',
        last_update: '21/Jan/2020',
        data: "23"
      }, {
        name: "sensor 2",
        id: '2',
        period: '1 Sample Every Seconds',
        last_update: '21/Jan/2020',
        data: "21"
      }, {
        name: "sensor 3",
        id: '3',
        period: '1 Sample Every Seconds',
        last_update: '21/Jan/2020',
        data: "24"
      }, {
        name: "sensor 4",
        id: '4',
        period: '1 Sample Every Seconds',
        last_update: '21/Jan/2020',
        data: "25"
      }, {
        name: "sensor 5",
        id: '5',
        period: '1 Sample Every Seconds',
        last_update: '21/Jan/2020',
        data: "23"
      },
    ]
  };
  handleModal = (visible) => {
    this.setState({visible})
  };

  render() {
    const {visible, sensors} = this.state;
    return (
      <Container className={"main-div-card"} fluid>
        <Container>
          <Row>
            <Col xs={12} className="p-0">
              <h4 className={"sensor-main-div"}>Sensor Viewer</h4>
              <Col xs={12} className={"sensor-id-search-div"}>
                <Row className="main-row">
                  <Col sm={2} xs={12} className={"p-0"}>
                    <span>Device ID:</span>
                  </Col>
                  <Col sm={10} xs={12}>
                    <InputGroup>
                      <FormControl
                        placeholder="Enter ID Here"
                        aria-label="Enter ID Here"
                        aria-describedby="basic"
                      />
                      <InputGroup.Append>
                        <Button>Submit</Button>
                      </InputGroup.Append>
                    </InputGroup>
                  </Col>
                </Row>
                <Row className={"card-main-row"}>
                  <Col xs={12} className="device-status-div">
                    <h5>
                      <span className="status-tag" style={{backgroundColor: '#008000'}}/>
                      Device Connected
                    </h5>
                  </Col>

                  <Col xs={12}>
                    <Accordion defaultActiveKey={0}>
                      {sensors.map((item, index) => {
                        return <Card key={index} className={'main-card'}>
                          <Card.Header>
                            <Accordion.Toggle as={Button} variant="link" eventKey={index}>
                              {item.name}
                              <img src={Images.down_arrow} alt={"down-arrow"}/>
                            </Accordion.Toggle>
                          </Card.Header>
                          <Accordion.Collapse eventKey={index}>
                            <Card.Body>
                              <ListGroup>
                                <ListGroup.Item>
                                  <span>Sensor Name:</span>{item.name}
                                </ListGroup.Item>
                                <ListGroup.Item>
                                  <span>Sensor Id:</span>
                                  {item.id}
                                </ListGroup.Item>
                                <ListGroup.Item>
                                  <span>Sampling Period:</span>
                                  {item.period}
                                </ListGroup.Item>
                                <ListGroup.Item>
                                  <span>Last Update:</span>
                                  {item.last_update}
                                </ListGroup.Item>
                                <ListGroup.Item className="temperature-list">
                                  <h1>{item.data} <span>&#8451;</span></h1>
                                </ListGroup.Item>
                              </ListGroup>
                            </Card.Body>
                          </Accordion.Collapse>
                        </Card>
                      })}
                    </Accordion>
                  </Col>
                </Row>
              </Col>
            </Col>
          </Row>
          <Modal
            show={visible}
            onHide={() => this.handleModal(false)}
            animation={true}
            centered={true}
            dialogClassName="main-modal"
            backdrop={false}>
            <Modal.Body>
              <Col xs={12}>
                <h6>Enter Your Details</h6>
              </Col>
              <Form>
                <Form.Group controlId="formRealmName">
                  <Form.Label>Realm Name</Form.Label>
                  <Form.Control type="text" placeholder="Enter Realm Name"/>
                </Form.Group>

                <Form.Group controlId="formRealmTokenNumber">
                  <Form.Label>Token</Form.Label>
                  <Form.Control type="text" placeholder="Enter Token Number"/>
                </Form.Group>
                <Button onClick={() => this.handleModal(false)} variant="primary" type="button">
                  Submit
                </Button>
              </Form>
            </Modal.Body>
          </Modal>
        </Container>
      </Container>
    );
  }
}

export default SensorViewer;
