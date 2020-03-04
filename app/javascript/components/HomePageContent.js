import React from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import SearchContextProvider from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'
import { Router } from '@reach/router'

/**
 * Wrapper component search and result panels
 */
export default function HomePageContent() {
  const SearchRoute = (props) => (
    <SearchContextProvider {...props}>
      <SearchPanel/>
      <ResultsPanel/>
    </SearchContextProvider>
  )
  return (
    <UserProvider>
      <SearchFacetProvider>
        <Router>
          <SearchRoute default/>
        </Router>
      </SearchFacetProvider>
    </UserProvider>
  )
}
