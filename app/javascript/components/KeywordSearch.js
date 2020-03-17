import React, { useState, useContext } from 'react'
import Button from 'react-bootstrap/lib/Button'
import InputGroup from 'react-bootstrap/lib/InputGroup'
import Form from 'react-bootstrap/lib/Form'
import { faSearch } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { StudySearchContext } from 'components/search/StudySearchProvider'

/**
 * Component to search using a keyword value
 * optionally takes a 'keywordValue' prop with the initial value for the field
 */
export default function KeywordSearch(props) {
  const searchContext = useContext(StudySearchContext)
  const [keywordValue, setKeywordValue] = useState(searchContext.params.terms)

  /**
   * Updates terms in search context upon submitting keyword search
   */
  function handleSubmit(submitValue) {
    event.preventDefault()
    searchContext.updateSearch({ terms: submitValue })
  }

  return (
    <Form
      horizontal
      onSubmit = {() => handleSubmit(keywordValue)}
      className='study-keyword-search'
    >
      <InputGroup>
        <input
          className="form-control"
          type="text"
          value={keywordValue}
          onChange={e => setKeywordValue(e.target.value) }
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
