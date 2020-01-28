import React from 'react';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faSearch } from '@fortawesome/free-solid-svg-icons';
import Col from 'react-bootstrap/Col';
import Button from 'react-bootstrap/Button';

export default function FiltersSearchBar(props) {
  const componentName = 'filters-search-bar';
  const filtersSearchBarID = `${componentName}-${props.filtersBoxID}`;

  const buttonStyle = {
    float: 'right',
    position: 'relative',
    top: '-2.4em',
    borderRadius: '0 4px 4px 0'
  }

  return (
    <div style={{margin: '2px'}}>
      <Form.Group controlId={filtersSearchBarID}>
        <Form.Control
          className={componentName}
          type="text"
          placeholder="Search"
        />
        <Button style={buttonStyle}>
          <FontAwesomeIcon icon={faSearch}/>
        </Button>
      </Form.Group>
    </div>
  );
}