import React, { useContext, useState } from 'react'
import { fetchSearch, buildSearchQueryString, buildFacetsFromQueryString } from 'lib/scp-api'
import _cloneDeep from 'lodash/cloneDeep'
import _assign from 'lodash/assign'
import _isEqual from 'lodash/isEqual'
import { navigate, useParams } from '@reach/router'
import * as queryString from 'query-string'
/* eslint-disable */
/*
  This is a single component and paired context that manages the search params and data
*/
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
  updateSearch: () => { throw new Error('You are trying to use this context outside of a Provider container') }
}

export const StudySearchContext = React.createContext(emptySearch)

export function useContextStudySearch() {
  return useContext(StudySearchContext)
}

export default function StudySearchProvider(props) {
  let defaultState = _cloneDeep(emptySearch)
  defaultState.updateSearch = updateSearch
  let [searchState, setSearchState] = useState(defaultState)
  const queryParams = queryString.parse(props.location.search);
  let updatedParams = {
    page: queryParams.page ? queryParams.page : 1,
    terms: queryParams.terms ? queryParams.terms : '',
    facets: buildFacetsFromQueryString(queryParams.facets)
  }

  // update the search criteria
  async function updateSearch(searchParams) {
    const effectiveParams = Object.assign(updatedParams, searchParams)
    // reset the page to 1 for new searches, unless otherwise specified
    if (!searchParams.page) {
      effectiveParams.page = 1
    }
    navigate('?' + buildSearchQueryString('study', effectiveParams.terms, effectiveParams.facets, effectiveParams.page))
  }

  //perform the actual API search
  async function performSearch(searchParams) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0,0)
    const results = await fetchSearch('study', searchParams.terms, searchParams.facets, searchParams.page)
    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: false,
      isLoaded: true,
      results: results,
      updateSearch: updateSearch
    })
  }

  if (!_isEqual(updatedParams, searchState.params) || !searchState.isLoading && !searchState.isLoaded) {
    performSearch(updatedParams)
    setSearchState({
      params: updatedParams,
      isError: false,
      isLoading: true,
      isLoaded: false,
      results: [],
      updateSearch: updateSearch
    })
  }

  return (
    <StudySearchContext.Provider value={searchState}>
      { props.children }
    </StudySearchContext.Provider>
  )
}
