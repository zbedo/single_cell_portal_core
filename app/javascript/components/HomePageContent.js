import React, { useState, useEffect } from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import { fetchSearch } from '../lib/scp-api'
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

