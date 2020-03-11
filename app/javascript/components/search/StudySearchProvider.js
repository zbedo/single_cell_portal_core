import React, { useContext, useState } from 'react'
import {
  fetchSearch, buildSearchQueryString, buildFacetsFromQueryString
} from 'lib/scp-api'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { Router, navigate } from '@reach/router'
import * as queryString from 'query-string'


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
  trigger: null,
  updateSearch: () => {
    throw new Error(
      'You are trying to use this context outside of a Provider container'
    )
  }
}

export const StudySearchContext = React.createContext(emptySearch)

export function useContextStudySearch() {
  return useContext(StudySearchContext)
}
/**
  * renders a StudySearchContext tied to its props,
  * fires route navigate on changes to params
  */
function StudySearchProvider(props) {
  const defaultState = _cloneDeep(emptySearch)
  defaultState.updateSearch = updateSearch
  const [searchState, setSearchState] = useState(defaultState)
  const [searchTrigger, setSearchTrigger] = useState(null)
  const searchParams = props.searchParams

  /**
   * Update search parameters in URL
   *
   * @param {Object} newParams Parameters to update
   * @param {Object} trigger Event that is triggering search; for analytics
   */
  async function updateSearch(newParams, trigger) {
    const facets = Object.assign({}, searchParams.facets, newParams.facets)
    const terms = ('terms' in newParams) ? newParams.terms : searchParams.terms
    // reset the page to 1 for new searches, unless otherwise specified
    const page = newParams.page ? newParams.page : 1
    const queryString = buildSearchQueryString('study', terms, facets, page)
    setSearchTrigger(trigger)
    navigate(`?${queryString}`)
  }

  /** perform the actual API search */
  async function performSearch(params) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)
    const results = await fetchSearch('study',
      params.terms,
      params.facets,
      params.page,
      searchTrigger)
    setSearchState({
      params,
      isError: false,
      isLoading: false,
      isLoaded: true,
      results,
      searchTrigger,
      updateSearch
    })
  }

  if (!_isEqual(searchParams, searchState.params) ||
      !searchState.isLoading &&
      !searchState.isLoaded) {
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
    <StudySearchContext.Provider value={searchState}>
      { props.children }
    </StudySearchContext.Provider>
  )
}

/**
  * Self-contained component for providing a url-routable
  * StudySearchContext and rendering children.
  * The routing is all via query params
  */
export default function RoutableStudySearchProvider(props) {
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
      <StudySearchProvider searchParams={searchParams}>
        {props.children}
      </StudySearchProvider>
    )
  }
  return (
    <Router>
      <SearchRoute default/>
    </Router>
  )
}
