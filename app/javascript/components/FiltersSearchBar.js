import React from 'react';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faSearch } from '@fortawesome/free-solid-svg-icons';
import Col from 'react-bootstrap/Col';

export default function FiltersSearchBar(props) {
  const componentName = 'filters-search-bar';
  const filtersSearchBarID = `${componentName}-${props.filtersBoxID}`;
  return (
    <div>
      {/* <InputGroup>
        <InputGroup.Prepend>
            <InputGroup.Text>
              <FontAwesomeIcon icon={faSearch} />
            </InputGroup.Text>
        </InputGroup.Prepend>
        <Form.Control
          id={filtersSearchBarID}
          type='text'
          placeholder='Search'
        />
      </InputGroup> */}
      {/* <FontAwesomeIcon icon={faCoffee} /> */}
      <Form>
      <Form.Row>
        <Form.Group as={Col} md="4" controlId="validationCustomUsername">
          <Form.Label>Username</Form.Label>
          <InputGroup>
            <InputGroup.Prepend>
              <InputGroup.Text id="inputGroupPrepend">@</InputGroup.Text>
            </InputGroup.Prepend>
            <Form.Control
              type="text"
              placeholder="Username"
              aria-describedby="inputGroupPrepend"
              required
            />
            <Form.Control.Feedback type="invalid">
              Please choose a username.
            </Form.Control.Feedback>
          </InputGroup>
        </Form.Group>
      </Form.Row>
      </Form>
    </div>
  );
}