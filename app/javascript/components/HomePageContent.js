import React from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import StudySearchProvider from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'
import FeatureFlagProvider from 'providers/FeatureFlagProvider'
import ErrorBoundary from 'lib/ErrorBoundary'

/**
 * Wrapper component for search and result panels
 */
export default function HomePageContent() {
  return (
    <ErrorBoundary>
      <UserProvider>
        <FeatureFlagProvider>
          <SearchFacetProvider>
            <StudySearchProvider>
              <ErrorBoundary>
                <SearchPanel/>
              </ErrorBoundary>
              <ErrorBoundary>
                <ResultsPanel/>
              </ErrorBoundary>
            </StudySearchProvider>
          </SearchFacetProvider>
        </FeatureFlagProvider>
      </UserProvider>
    </ErrorBoundary>
  )
}
