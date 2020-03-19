import React, { useContext } from 'react'
import Button from 'react-bootstrap/lib/Button'
import InputGroup from 'react-bootstrap/lib/InputGroup'
import Form from 'react-bootstrap/lib/Form'
import { faSearch } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { SearchSelectionContext } from './search/SearchSelectionProvider'

/**
 * Component to search using a keyword value
 * optionally takes a 'keywordValue' prop with the initial value for the field
 */
export default function KeywordSearch() {
  const selectionContext = useContext(SearchSelectionContext)
  /**
   * Updates terms in search context upon submitting keyword search
   */
  function handleSubmit(event) {
    event.preventDefault()
    selectionContext.performSearch()
  }

  function handleKeywordChange(newValue) {
    selectionContext.updateSelection({terms: newValue})
  }

  return (
    <Form
      horizontal
      onSubmit = { handleSubmit }
      className='study-keyword-search'
    >
      <InputGroup>
        <input
          className="form-control"
          type="text"
          value={selectionContext.terms}
          onChange={e => handleKeywordChange(e.target.value) }
          placeholder="Enter keyword"
          name="keywordText"/>
        <div className="input-group-append">
          <Button type='submit'>
            <FontAwesomeIcon icon={faSearch} />
          </Button>
        </div>
      </InputGroup>
    </Form>
  )
}
