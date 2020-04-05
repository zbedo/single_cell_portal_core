import React, { useState, useContext } from 'react'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { navigate, useLocation } from '@reach/router'
import * as queryString from 'query-string'

import { fetchSearch, buildSearchQueryString, buildFacetsFromQueryString } from 'lib/scp-api'
import { StudySearchContext } from 'providers/StudySearchProvider'

const emptySearch = {
  params: {
    genes: '',
    genePage: 1
  },

  results: [],
  studyResults: [],
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
  const studySearchState = useContext(StudySearchContext)

  /**
   * Update search parameters in URL
   *
   * @param {Object} newParams Parameters to update
   */
  async function updateSearch(newParams, studySearchState, searchWithinStudies) {

    let mergedParams = Object.assign({}, newParams)
    if (searchWithinStudies) {
      mergedParams = Object.assign(mergedParams, studySearchState.params)
    }
    const queryString = buildSearchQueryString('study', newParams)
    navigate(`?${queryString}`)
  }

  /** perform the actual API search */
  async function performSearch(params, studySearchState) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)
    let studyAccessions = undefined
    if (studySearchState.isLoaded) {
      params.accessions = studySearchState.results.matchingAccessions
    }
    const studyResults = await fetchSearch('study', params)

    setSearchState({
      params,
      isError: false,
      isLoading: false,
      isLoaded: true,
      studyResults,
      updateSearch
    })
  }

  // Search done on initial page load only if genes are specified
  if (searchParams.genes.length &&
      (!_isEqual(searchParams, searchState.params) ||
      !searchState.isLoading &&
      !searchState.isLoaded)) {
    performSearch(searchParams, studySearchState)

    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: true,
      isLoaded: false,
      results: [],
      studyResults: [],
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
 * GeneSearchContext and rendering children.
 * The routing is all via query params
 */
export default function GeneSearchProvider(props) {
  const location = useLocation()
  const queryParams = queryString.parse(location.search)
  const searchParams = {
    genePage: queryParams.genePage ? parseInt(queryParams.genePage) : 1,
    genes: queryParams.genes ? queryParams.genes : ''
  }
  return (
    <PropsGeneSearchProvider searchParams={searchParams}>
      {props.children}
    </PropsGeneSearchProvider>
  )
}
