import React, { useContext, useState, useEffect, useRef } from 'react'
import Button from 'react-bootstrap/lib/Button'
import InputGroup from 'react-bootstrap/lib/InputGroup'
import Form from 'react-bootstrap/lib/Form'
import { faSearch, faTimes } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { SearchSelectionContext } from './search/SearchSelectionProvider'
import { StudySearchContext } from './search/StudySearchProvider'

/**
 * Component to search using a keyword value
 * optionally takes a 'keywordValue' prop with the initial value for the field
 */
export default function KeywordSearch({ keywordPrompt }) {
  const placeholder = keywordPrompt ? keywordPrompt : 'Enter keyword'
  const selectionContext = useContext(SearchSelectionContext)
  const searchContext = useContext(StudySearchContext)
  // show clear button after a search has been done,
  //  as long as the text hasn't been updated
  const showClear = searchContext.params.terms === selectionContext.terms &&
                    selectionContext.terms != ''
  // Store a reference to the input's DOM node
  const inputRef = useRef()
  const [value, setValue] = useState(selectionContext.terms)
  /**
   * Updates terms in search context upon submitting keyword search
   */
  function handleSubmit(event) {
    event.preventDefault()
    if (showClear) {
      selectionContext.updateSelection({ terms: '' }, true)
    }
    selectionContext.updateSelection({ terms: value })
  }

  function handleKeywordChange(newValue) {
    setValue(newValue)
  }

  useEffect(() => {
  }, [useRef, selectionContext.selection, showClear])
  return (
    <Form
      horizontal
      onSubmit = { handleSubmit }
      className='study-keyword-search'
    >
      <InputGroup>
        <input
          ref={inputRef}
          className="form-control"
          size="30"
          type="text"
          value={value}
          onChange={e => handleKeywordChange(e.target.value) }
          placeholder={placeholder}
          name="keywordText"/>
        <div className="input-group-append">
          <Button type='submit'>
            <FontAwesomeIcon icon={ showClear ? faTimes : faSearch } />
          </Button>
        </div>
      </InputGroup>
    </Form>
  )
}
