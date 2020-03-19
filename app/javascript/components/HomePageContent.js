import React from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import StudySearchProvider from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'

/**
 * Wrapper component for search and result panels
 */
export default function HomePageContent() {
  return (
    <UserProvider>
      <SearchFacetProvider>
        <StudySearchProvider>
          <SearchPanel/>
          <ResultsPanel/>
        </StudySearchProvider>
      </SearchFacetProvider>
    </UserProvider>
  )
}
