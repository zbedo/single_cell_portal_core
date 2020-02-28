import React from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import SearchContextProvider from 'components/search/StudySearchProvider'

/**
 * Wrapper component search and result panels
 */
export default function HomePageContent() {
  return (
    <SearchContextProvider>
      <SearchPanel/>
      <ResultsPanel/>
    </SearchContextProvider>
  )
}
