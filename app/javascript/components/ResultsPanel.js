import React, { useContext } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import StudyResults from 'components/StudyResults'
/**
 * Component for Results displayed on the homepage
 */
const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
  let displayedResults = <span></span>
  if (searchContext.isLoaded) {
    if (searchContext.results.studies.length>0) {
      displayedResults = <StudyResults
        results={searchContext.results}
        handlePageTurn={pageNum => {searchContext.updateSearch({ page: pageNum })}}
      />
    } else {
      displayedResults = <p>No Results</p>
    }
  }
  return (
    <div id="results-panel">
      {displayedResults}
    </div>
  )
}

export default ResultsPanel
