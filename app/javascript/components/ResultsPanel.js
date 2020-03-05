import React, { useContext } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import StudyResults from './StudyResults'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons';

/**
 * Component for Results displayed on the homepage
 */
const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
  var panelContent
  if (searchContext.isError) {
    panelContent = <div className="error-panel"><FontAwesomeIcon icon={faExclamantionCircle}/> Sorry, an error has occurred.  Support has been notified.  Please try again.</div>
  } else if (!searchContext.isLoaded) {
    panelContent = <div className="loading-panel">Loading &nbsp; <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/></div>
  } else if (searchContext.results.studies.length > 0) {
    panelContent = <StudyResults
        results={searchContext.results}
        changePage={pageNum => {searchContext.updateSearch({ page: pageNum })}}
      />
  } else {
    panelContent = <p>No Results</p>
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
