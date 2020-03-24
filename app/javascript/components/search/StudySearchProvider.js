import React, { useContext, useState } from 'react'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { navigate, useLocation } from '@reach/router'
import * as queryString from 'query-string'

import {
  fetchSearch, buildSearchQueryString, buildFacetsFromQueryString
} from 'lib/scp-api'
import SearchSelectionProvider from 'components/search/SearchSelectionProvider'

const emptySearch = {
  params: {
    terms: '',
    facets: {},
    page: 1
  },

  results: [],
  isLoading: false,
  isLoaded: false,
  isError: false,

  updateSearch: () => {
    throw new Error(
      'You are trying to use this context outside of a Provider container'
    )
  },
  performSearch: () => {
    throw new Error(
      'You are trying to use this context outside of a Provider container'
    )
  }
}

export const StudySearchContext = React.createContext(emptySearch)


/**
 * Count terms, i.e. space-delimited strings, and consider [""] to have 0 terms
 */
export function getNumberOfTerms(terms) {
  let numTerms = 0
  const splitTerms = terms.split(' ')
  if (splitTerms.length > 0 && splitTerms[0] !== '') {
    numTerms = splitTerms.length
  }
  return numTerms
}

/**
 * Counts facets (e.g. species, disease) and filters (e.g. human, COVID-19)
 */
export function getNumFacetsAndFilters(facets) {
  const numFacets = Object.keys(facets).length
  const numFilters =
    Object.values(facets).reduce((prevNumFilters, filterArray) => {
      return prevNumFilters + filterArray.length
    }, 0)

  return [numFacets, numFilters]
}

/** Determine if search has any parameters, i.e. terms or filters */
export function hasSearchParams(params) {
  const numTerms = getNumberOfTerms(params.terms)
  const [numFacets, numFilters] = getNumFacetsAndFilters(params.facets)
  return (numTerms + numFacets + numFilters) > 0
}

/** Wrapper for deep mocking via Jest / Enzyme */
export function useContextStudySearch() {
  return useContext(StudySearchContext)
}

/**
  * renders a StudySearchContext tied to its props,
  * fires route navigate on changes to params
  */
export function PropsStudySearchProvider(props) {
  let startingState = _cloneDeep(emptySearch)
  startingState.params = props.searchParams
  // attach the perform and update methods to the context to avoid prop-drilling
  startingState.performSearch = performSearch
  startingState.updateSearch = updateSearch
  const [searchState, setSearchState] = useState(startingState)
  const searchParams = props.searchParams

  /**
   * Update search parameters in URL
   * @param {Object} newParams Parameters to update
   */
  async function updateSearch(newParams) {
    const facets = Object.assign({}, searchParams.facets, newParams.facets)
    const terms = ('terms' in newParams) ? newParams.terms : searchParams.terms
    // reset the page to 1 for new searches, unless otherwise specified
    const page = newParams.page ? newParams.page : 1
    const queryString = buildSearchQueryString('study', terms, facets, page)
    navigate(`?${queryString}`)
  }

  /** perform the actual API search based on current params */
  async function performSearch() {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)

    const results = await fetchSearch('study',
      searchParams.terms,
      searchParams.facets,
      searchParams.page)

    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: false,
      isLoaded: true,
      results,
      updateSearch
    })
  }

  if (!_isEqual(searchParams, searchState.params)) {
    performSearch()
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
    <StudySearchContext.Provider value={searchState}>
      <SearchSelectionProvider>
        { props.children }
      </SearchSelectionProvider>
    </StudySearchContext.Provider>
  )
}


/**
 * Self-contained component for providing a url-routable
 * StudySearchContext and rendering children.
 * The routing is all via query params
 */
export default function StudySearchProvider(props) {
  const location = useLocation()
  const queryParams = queryString.parse(location.search)
  const searchParams = {
    page: queryParams.page ? queryParams.page : 1,
    terms: queryParams.terms ? queryParams.terms : '',
    facets: buildFacetsFromQueryString(queryParams.facets)
  }
  return (
    <PropsStudySearchProvider searchParams={searchParams}>
      {props.children}
    </PropsStudySearchProvider>
  )
}
