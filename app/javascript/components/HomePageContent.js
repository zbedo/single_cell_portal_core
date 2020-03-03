import React from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import SearchContextProvider from 'components/search/StudySearchProvider'
import UserProvider from 'components/UserProvider'

/**
 * Wrapper component search and result panels
 */
export default function HomePageContent() {
  return (
    <UserProvider>
      <SearchContextProvider>
        <SearchPanel/>
        <ResultsPanel/>
      </SearchContextProvider>
    </UserProvider>
  )
}
