import React from 'react';
import Form from 'react-bootstrap/Form';

export default function FiltersSearchBar(props) {
  const componentName = 'filters-search-bar';
  const filtersSearchBarID = `${componentName}-${props.filtersBoxID}`;
  return (
    <div>
      <Form.Group controlId={filtersSearchBarID}>
        <Form.Control
          id={filtersSearchBarID}
          className={componentName}
          type="text"
          placeholder="Search"
        />
      </Form.Group>
    </div>
  );
}