import React, { useState } from 'react';
import Form from 'react-bootstrap/lib/Form';
import FormControl from 'react-bootstrap/lib/FormControl';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faSearch } from '@fortawesome/free-solid-svg-icons';
import Button from 'react-bootstrap/lib/Button';

/**
 * Component to search filters within a given facet
 * Used when facet has many available filters (e.g. disease)
 *
 * Stub, will develop.
 */
export default function FiltersSearchBar(props) {

  return (
    <div class='filters-search-bar'>
      <Form onSubmit={props.onSubmit}>
        <FormControl
          id={props.id}
          type='text'
          autoComplete='false'
          placeholder='Search'
        />
        <Button className='search-button' onClick={props.onClick}>
          <FontAwesomeIcon icon={faSearch}/>
        </Button>
      </Form>
    </div>
  );
}
