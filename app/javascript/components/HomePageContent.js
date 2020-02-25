import React, { useState, useEffect } from 'react'
import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import { fetchSearch } from '../lib/scp-api'

/**
 * Wrapper component search and result panels
 */
export default function HomePageContent() {
  const [results, setResults] = useState('')
  const [keyword, setKeyword] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const [type] = useState('study')

  const handleKeywordUpdate = keyword => {
    setKeyword(keyword)
  }


  useEffect(() => {
    const fetchData = async () => {
      const results = await fetchSearch(type, keyword, '', currentPage)
      setResults(results)
      console.log(results)
    }
    fetchData()
  }, [keyword, currentPage])

  return (
    <div>
      <SearchPanel updateKeyword={handleKeywordUpdate}/>
      {results && <ResultsPanel results={results}/>}
    </div>
  )
}

