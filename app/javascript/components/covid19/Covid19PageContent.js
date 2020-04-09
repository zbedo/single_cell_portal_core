import React from 'react'
import { Router } from '@reach/router'

import SearchPanel from 'components/search/controls/SearchPanel'
import ResultsPanel from 'components/search/results/ResultsPanel'
import StudySearchProvider from 'providers/StudySearchProvider'
import SearchFacetProvider from 'providers/SearchFacetProvider'
import UserProvider from 'providers/UserProvider'
import ErrorBoundary from 'lib/ErrorBoundary'

/**
 * Wrapper component for search and result panels
 */
export default function Covid19PageContent() {
  return (
    <Router>
      <UnroutedPageContent default/>
    </Router>
  )
}

function UnroutedPageContent() {
  return (
    <ErrorBoundary>
      <UserProvider>
        <SearchFacetProvider>
          <StudySearchProvider preset="covid19" >
            <ErrorBoundary>
              <SearchPanel showCommonButtons={false}
                showDownloadButton={false}
                keywordPrompt="Search within COVID-19 studies"
                searchOnLoad={true}/>
            </ErrorBoundary>
            <ErrorBoundary>
              <ResultsPanel/>
            </ErrorBoundary>
          </StudySearchProvider>
        </SearchFacetProvider>
      </UserProvider>
    </ErrorBoundary>
  )
}
