import React, { useContext, useState } from 'react'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { Router, navigate } from '@reach/router'
import * as queryString from 'query-string'

import {
  fetchSearch, buildSearchQueryString, buildFacetsFromQueryString,
  fetchDownloadSize
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

  downloadSize: {},
  isLoadingDownloadSize: false,
  isLoadedDownloadSize: false,

  updateSearch: () => {
    throw new Error(
      'You are trying to use this context outside of a Provider container'
    )
  }
}

export const StudySearchContext = React.createContext(emptySearch)

/** Wrapper for deep mocking via Jest / Enzyme */
export function useContextStudySearch() {
  return useContext(StudySearchContext)
}

/**
  * renders a StudySearchContext tied to its props,
  * fires route navigate on changes to params
  */
export function PropsStudySearchProvider(props) {
  const defaultState = _cloneDeep(emptySearch)
  defaultState.updateSearch = updateSearch
  const [searchState, setSearchState] = useState(defaultState)
  const downloadSize = emptySearch.downloadSize
  const searchParams = props.searchParams

  /**
   * Update search parameters in URL
   *
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

  /** Update size preview for bulk download */
  async function updateDownloadSize(params, results) {
    const accessions = results.matchingAccessions
    const fileTypes = ['Expression', 'Metadata']
    const size = await fetchDownloadSize(accessions, fileTypes)

    setSearchState({
      params,
      isError: false,
      isLoading: false,
      isLoaded: true,

      isLoadingDownloadSize: false,
      isLoadedDownloadSize: true,
      downloadSize: size,

      results,
      updateSearch
    })
  }

  /** perform the actual API search */
  async function performSearch(params) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)

    const results = await fetchSearch('study',
      params.terms,
      params.facets,
      params.page)

    setSearchState({
      params,
      isError: false,
      isLoading: false,
      isLoaded: true,
      isLoadingDownloadSize: true,
      isLoadedDownloadSize: false,
      results,
      downloadSize: {},
      updateSearch
    })

    updateDownloadSize(params, results)
  }

  // Search done on initial page load
  if (!_isEqual(searchParams, searchState.params) ||
      !searchState.isLoading &&
      !searchState.isLoaded) {
    performSearch(searchParams)

    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: true,
      isLoaded: false,
      isLoadingDownloadSize: false,
      isLoadedDownloadSize: false,
      results: [],
      downloadSize,
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
  // create a wrapper component for the search display since <Router>
  // assumes that all of its unwrapped children (even nested) be routes
  const SearchRoute = routerProps => {
    const queryParams = queryString.parse(routerProps.location.search)
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
  return (
    <Router>
      <SearchRoute default/>
    </Router>
  )
}
