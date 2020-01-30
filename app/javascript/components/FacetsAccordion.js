import React, { useState } from 'react';
import Button from 'react-bootstrap/Button';
import Accordion from 'react-bootstrap/Accordion';
import Card from 'react-bootstrap/Card';
import InputGroup from 'react-bootstrap/InputGroup';

export default function FacetsAccordion(props) {
  return (
    // Accordions provide a way to restrict Card components to only open one at a time.
    // https://react-bootstrap.github.io/components/accordion/
    <Accordion defaultActiveKey="0">
      {
        props.facets.map((facet) => {
          return (
          <Card>
              <Card.Header>
                <Accordion.Toggle as={Button} variant="link" eventKey="0">
                  {facet.name}
                </Accordion.Toggle>
              </Card.Header>
              <Accordion.Collapse eventKey="0">
              <Card.Body>
                {
                  facet.filters.map((d) => {
                    const id = `filter-${facet.name}-${d.id}`;
                    return (
                      <li key={'li-' + id}>
                        <InputGroup.Checkbox
                          id={id}
                          aria-label="Checkbox"
                          name={id}
                          // onClick={handleFilterClick}
                        />
                        <label htmlFor={id}>{d.name}</label>
                      </li>
                    );
                  })
              }
              </Card.Body>
              </Accordion.Collapse>
            </Card>
          );
        })
      }
    </Accordion>
  );
}