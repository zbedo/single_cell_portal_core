import React, { useContext } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import StudyResultsContainer from './StudyResultsContainer'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons'

/**
 * Component for Results displayed on the homepage
 */
const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
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
  } else if (searchContext.results.studies.length > 0) {
    panelContent =
      <StudyResultsContainer
        results={searchContext.results}
        changePage={pageNum => {searchContext.updateSearch({ page: pageNum })}}
      />
  } else {
    panelContent = <p>No results</p>
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
