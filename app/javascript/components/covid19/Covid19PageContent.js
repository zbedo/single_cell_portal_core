import React from 'react'
import SearchPanel from 'components/SearchPanel'
import ResultsPanel from 'components/ResultsPanel'
import StudySearchProvider from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'
import ErrorBoundary from 'lib/ErrorBoundary'

/**
 * Wrapper component for search and result panels
 */
export default function Covid19PageContent() {
  return (
    <ErrorBoundary>
      <UserProvider>
        <SearchFacetProvider>
          <StudySearchProvider preset="covid19" >
            <ErrorBoundary>
              <SearchPanel showCommonButtons={false}
                           showDownloadButton={false}
                           keywordPrompt="Search within COVID-19 studies"/>
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
