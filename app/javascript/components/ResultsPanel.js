import React, { useContext } from 'react'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import StudyResultsContainer from './StudyResults'
/**
 * Component for Results displayed on the homepage
 */
const ResultsPanel = props => {
  const searchContext = useContext(StudySearchContext)
  let displayedResults = <span></span>
  if (searchContext.isLoaded) {
    if (searchContext.results.studies.length > 0) {
      displayedResults = <StudyResultsContainer
        results={searchContext.results}
        handlePageTurn={pageNum => {searchContext.updateSearch({ page: pageNum })}}
      />
    } else {
      displayedResults = <p>No results</p>
    }
  }
  return (
    <div className="results-panel">
      {displayedResults}
    </div>
  )
}

export default ResultsPanel
