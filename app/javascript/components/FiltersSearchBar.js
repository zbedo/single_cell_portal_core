import React from 'react'
import Form from 'react-bootstrap/lib/Form'
import FormControl from 'react-bootstrap/lib/FormControl'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faSearch } from '@fortawesome/free-solid-svg-icons'
import Button from 'react-bootstrap/lib/Button'

/**
 * Component to search filters within a given facet
 * Used when facet has many available filters (e.g. disease)
 */
export default function FiltersSearchBar(props) {
  const filtersSearchBarId = `filters-search-bar-${props.filtersBoxId}`

  async function handleFilterSearchSubmit(event) {
    event.preventDefault()
    const terms = document.getElementById(filtersSearchBarId).value
    await props.searchFilters(terms)
  }

  async function handleFilterSearchButtonClick() {
    const terms = document.getElementById(filtersSearchBarId).value
    await props.searchFilters(terms)
  }

  return (
    <div className='filters-search-bar'>
      <Form onSubmit={handleFilterSearchSubmit}>
        <FormControl
          id={filtersSearchBarId}
          type='text'
          autoComplete='false'
          placeholder='Search for a filter'
        />
        <Button
          className='search-button'
          onClick={handleFilterSearchButtonClick}
        >
          <FontAwesomeIcon icon={faSearch}/>
        </Button>
      </Form>
    </div>
  )
}
