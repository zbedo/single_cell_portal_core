import React, { useState } from 'react';
import Button from 'react-bootstrap/Button';
import Accordion from 'react-bootstrap/Accordion';
import Card from 'react-bootstrap/Card';
import InputGroup from 'react-bootstrap/InputGroup';

export default function FacetsAccordion(props) {
  console.log('props.facets')
  console.log(props.facets)
  return (
    // Accordions provide a way to restrict Card components to only open one at a time.
    // https://react-bootstrap.github.io/components/accordion/
    <Accordion defaultActiveKey="0">
      {
        props.facets.map((facet) => {
          <Card>
          <Card.Header>
            <Accordion.Toggle as={Button} variant="link" eventKey="0">
              {facet.name}
            </Accordion.Toggle>
          </Card.Header>
          <Accordion.Collapse eventKey="0">
            <Card.Body>
              <ul>
                {
                  // Consider abstracting this and similar code block in
                  // FiltersBox into new FiltersList component
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
              </ul>
            </Card.Body>
          </Accordion.Collapse>
        </Card>
        })
      }
    </Accordion>
  );
}