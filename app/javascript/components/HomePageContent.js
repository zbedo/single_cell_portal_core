import React, { useContext, useEffect } from 'react'
import { Router, Link, useLocation } from '@reach/router'

import SearchPanel from './SearchPanel'
import GeneSearchView from 'components/search/genes/GeneSearchView'
import GeneSearchProvider from 'components/search/genes/GeneSearchProvider'
import ResultsPanel from './ResultsPanel'
import StudySearchProvider, { StudySearchContext } from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'

const StudySearchView = function() {
  const studySearchState = useContext(StudySearchContext)

  useEffect(() => {
    // if a search isn't already happening, perform one
    if (!studySearchState.isLoading && !studySearchState.isLoaded) {
      studySearchState.performSearch()
    }
  })

  return <><SearchPanel/><ResultsPanel/></>
}

const LinkableSearchTabs = function(props) {
  // we can't use the regular ReachRouter methods for link highlighting since the Reach
  // router doesn't own the home path
  const location = useLocation()
  const isShowGenes = location.pathname.startsWith('/single_cell/app/genes')
  return (
    <div>
      <nav className="nav search-links">
        <Link to={`/single_cell/app/studies${location.search}`} className={isShowGenes ? '' : 'active'}>
          <span className="fas fa-book"></span> Search Studies
        </Link>
        <Link to={`/single_cell/app/genes${location.search}`} className={isShowGenes ? 'active' : ''}>
          <span className="fas fa-dna"></span> Search Genes (R)
        </Link>
      </nav>
      <div className="tab-content top-pad">
        <Router basepath="/single_cell">
          <GeneSearchView path="app/genes"/>
          <StudySearchView default/>
        </Router>
      </div>
    </div>
  )
}

/**
 * Wrapper component for search and result panels
 */
function RawHomePageContent() {
  return (
    <UserProvider>
      <SearchFacetProvider>
        <StudySearchProvider>
          <GeneSearchProvider>
            {
              window.SCP.featureFlags.linkable_gene_search
                ? <LinkableSearchTabs/>
                : <StudySearchView/>
            }
          </GeneSearchProvider>
        </StudySearchProvider>
      </SearchFacetProvider>
    </UserProvider>
  )
}

export default function HomePageContent() {
  return (<Router>
    <RawHomePageContent default/>
  </Router>)
}
