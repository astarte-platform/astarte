import {Accordion, Button, Card, ListGroup} from "react-bootstrap";
import React from "react";

const _ = require("lodash");


function listItem(item, index) {
    return (
        <ListGroup.Item
            key={index}
            className="border-0 px-0 py-2 font-weight-normal text-capitalize bg-transparent"
        >
            <span className="pr-2 text-dark font-weight-bold">{item.label}:</span>
            {item.value}
        </ListGroup.Item>
    );
}

function SensorListItem(props) {
    const sensor_items = [
        {
            label: "Sampling Status",
            value: _.get(props.sampling, "enable") ? "Enable" : "Disable"
        },
        {
            label: "Sensor ID",
            value: props.item
        },
        {
            label: "Sampling Period",
            value: _.get(props.sampling, "samplingPeriod", "N/A")
        },
    ];
    return (
        <Card className="main-card border-0 mb-4">
            <Card.Header className="px-3 py-0 bg-white">
                <Accordion.Toggle
                    className="text-dark border-0 font-weight-bold text-uppercase w-100 text-left p-0 text-decoration-none"
                    as={Button}
                    variant="link"
                    eventKey={props.item}>
                    {_.get(props.available, "name", props.item)}
                </Accordion.Toggle>
            </Card.Header>
            <Accordion.Collapse eventKey={props.item}>
                <Card.Body className="p-3">
                    <ListGroup className="px-4 py-3 my-2 ">
                        {sensor_items.map(listItem)}
                    </ListGroup>
                </Card.Body>
            </Accordion.Collapse>
        </Card>
    );
}

export default function SensorItems(props) {
    const {sensorValues, sensorSamplingRate} = props;
    return Object.keys(sensorValues).map((item, index) => {
        return (
            <SensorListItem
                key={index}
                item={item}
                sensorValues={sensorValues}
                sampling={sensorSamplingRate[item]}
            />
        );
    });
}