import React from 'react'
import Button from 'react-bootstrap/lib/Button'
import InputGroup from 'react-bootstrap/lib/InputGroup'
import Form from 'react-bootstrap/lib/Form'
import { faSearch } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'

/**
 * Component to search using a keyword value
 *
 */
export default function KeywordSearch(props) {
  const handleSubmit = event => {
    // Prevent full page reload
    event.preventDefault()
    const searchTerm = event.target.keywordText.value.trim()
    if (searchTerm) {
      props.updateKeyword(searchTerm)
    };
  }

  return (
    <Form horizontal onSubmit = {handleSubmit} id='keyword-search' >
      <InputGroup id='keyword-input-group'>
        <input
          id="keyword-input"
          type="text"
          placeholder="Enter keyword"
          name="keywordText"/>
        <div id='keyword-submit'>
          <Button type='submit'>
            <FontAwesomeIcon icon={faSearch} />
          </Button>
        </div>
      </InputGroup>
    </Form>

  )
}
