import React, { useState } from 'react'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { navigate, useLocation } from '@reach/router'
import * as queryString from 'query-string'

import { fetchGeneSearch, buildGeneSearchQueryString, buildFacetsFromQueryString } from 'lib/scp-api'
import { StudySearchContext } from 'components/search/StudySearchProvider'

const emptySearch = {
  params: {
    genes: '',
    genePage: 1
  },

  results: [],
  isLoading: false,
  isLoaded: false,
  isError: false,

  updateSearch: () => {
    throw new Error(
      'You are trying to use this context outside of a Provider container'
    )
  }
}

export const GeneSearchContext = React.createContext(emptySearch)

/**
  * renders a GeneSearchContext tied to its props,
  * fires route navigate on changes to params
  */
export function PropsGeneSearchProvider(props) {
  const defaultState = _cloneDeep(emptySearch)
  defaultState.updateSearch = updateSearch
  const [searchState, setSearchState] = useState(defaultState)
  const searchParams = props.searchParams

  /**
   * Update search parameters in URL
   *
   * @param {Object} newParams Parameters to update
   */
  async function updateSearch(newParams, studySearchState) {
    const genes = ('genes' in newParams) ? newParams.genes : searchParams.genes
    // reset the page to 1 for new searches, unless otherwise specified
    const genePage = newParams.genePage ? newParams.genePage : 1
    const facets = studySearchState.params.facets
    const terms = studySearchState.params.terms
    let studyAccessions = []
    if (studySearchState.isLoaded) {
      studyAccessions = studySearchState.results.matchingAccessions
    }

    const queryString = buildGeneSearchQueryString(genes, studyAccessions, terms, facets, genePage)
    navigate(`?${queryString}`)
  }

  /** perform the actual API search */
  async function performSearch(params) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)

    const results = await fetchGeneSearch(
      params.genes,
      params.studyAccessions,
      params.terms,
      params.facets,
      params.genePage)

    setSearchState({
      params,
      isError: false,
      isLoading: false,
      isLoaded: true,
      results,
      updateSearch
    })
  }

  // Search done on initial page load only if genes are specified
  if (searchParams.genes.length &&
      (!_isEqual(searchParams, searchState.params) ||
      !searchState.isLoading &&
      !searchState.isLoaded)) {
    performSearch(searchParams)

    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: true,
      isLoaded: false,
      results: [],
      updateSearch
    })
  }
  return (
    <GeneSearchContext.Provider value={searchState}>
      { props.children }
    </GeneSearchContext.Provider>
  )
}


/**
 * Self-contained component for providing a url-routable
 * StudySearchContext and rendering children.
 * The routing is all via query params
 */
export default function GeneSearchProvider(props) {
  // create a wrapper component for the search display since <Router>
  // assumes that all of its unwrapped children (even nested) be routes
  const location = useLocation()
  const queryParams = queryString.parse(location.search)
  const searchParams = {
    genePage: queryParams.genePage ? queryParams.genePage : 1,
    genes: queryParams.genes ? queryParams.genes : '',
    page: queryParams.page ? queryParams.page : 1,
    terms: queryParams.terms ? queryParams.terms : '',
    facets: buildFacetsFromQueryString(queryParams.facets)
  }
  return (
    <PropsGeneSearchProvider searchParams={searchParams}>
      {props.children}
    </PropsGeneSearchProvider>
  )
}
