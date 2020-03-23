import React, { useContext } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons'

import { StudySearchContext } from 'components/search/StudySearchProvider'
import { StudyResults } from './StudyResultsContainer'
import SearchQueryDisplay from './SearchQueryDisplay'

/**
 * Component for Results displayed on the homepage
 */
const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
  const results = searchContext.results
  let panelContent
  if (searchContext.isError) {
    panelContent =
      <div className="error-panel">
        <FontAwesomeIcon icon={faExclamationCircle}/>
        Sorry, an error has occurred.  Support has been notified.
        Please try again.
      </div>
  } else if (!searchContext.isLoaded) {
    panelContent =
      <div className="loading-panel">
        Loading &nbsp;
        <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/>
      </div>
  } else if (results.studies && results.studies.length > 0) {
    panelContent =
      <>
        <SearchQueryDisplay terms={results.termList} facets={results.facets}/>
        <StudyResults
          results={results}
          changePage={pageNum => {searchContext.updateSearch({ page: pageNum })}}
        />
      </>
  } else {
    panelContent = (<>
      <SearchQueryDisplay terms={results.termList} facets={results.facets}/>
      <p>No results</p>
    </>)
  }
  return (
    <div className="results-panel">
      <div className="results-content">
        {panelContent}
      </div>
    </div>
  )
}

export default ResultsPanel
