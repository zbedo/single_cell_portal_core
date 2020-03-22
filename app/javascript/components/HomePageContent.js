import React from 'react'
import { Router, Link } from '@reach/router'

import SearchPanel from './SearchPanel'
import ResultsPanel from './ResultsPanel'
import StudySearchProvider from 'components/search/StudySearchProvider'
import SearchFacetProvider from 'components/search/SearchFacetProvider'
import UserProvider from 'components/UserProvider'


const GeneSearchView = function() {
  return <span> yoooooo Genes </span>
}

const StudySearchView = function() {
  return <><SearchPanel/><ResultsPanel/></>
}

const LinkableSearchTabs = function(props) {
  return (
    <div>
      <ul className="nav nav-tabs sc-tabs" role="tablist" id="home-page-tabs">
        <li role="presentation" className="home-nav active" id="search-studies-nav">
          <Link to="/single_cell/app/studies"> <span className="fas fa-book"></span> Search Studies</Link>
        </li>
        <li role="presentation" className="home-nav" id="search-genes-nav">
          <Link to="/single_cell/app/genes"> <span className="fas fa-dna"></span> Search Genes REACT</Link>
        </li>
      </ul>
      <div className="tab-content top-pad">
        <Router basepath="/single_cell">
          <StudySearchView path="app/studies"/>
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
export default function HomePageContent() {
  return (
    <UserProvider>
      <SearchFacetProvider>
        <StudySearchProvider>
          {
            window.SCP.featureFlags.linkable_gene_search
              ? <LinkableSearchTabs/>
              : <StudySearchView/>
          }
        </StudySearchProvider>
      </SearchFacetProvider>
    </UserProvider>
  )
}
