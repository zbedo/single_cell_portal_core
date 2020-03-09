import React, { useContext, useState } from 'react'
import {
  fetchSearch, buildSearchQueryString, buildFacetsFromQueryString
} from 'lib/scp-api'
import _cloneDeep from 'lodash/cloneDeep'
import _isEqual from 'lodash/isEqual'
import { navigate } from '@reach/router'
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
  Component and paired context that manage search params and data
*/
export default function StudySearchProvider(props) {
  const defaultState = _cloneDeep(emptySearch)
  defaultState.updateSearch = updateSearch
  const [searchState, setSearchState] = useState(defaultState)
  const queryParams = queryString.parse(props.location.search)
  const updatedParams = {
    page: queryParams.page ? queryParams.page : 1,
    terms: queryParams.terms ? queryParams.terms : '',
    facets: buildFacetsFromQueryString(queryParams.facets)
  }

  /**
  * update the search criteria
  */
  async function updateSearch(searchParams) {
    const effectiveFacets =
      Object.assign({}, updatedParams.facets, searchParams.facets)
    const effectiveTerms =
      ('terms' in searchParams) ? searchParams.terms : updatedParams.terms
    // reset the page to 1 for new searches, unless otherwise specified
    const effectivePage = searchParams.page ? searchParams.page : 1

    navigate(`?${buildSearchQueryString(
      'study', effectiveTerms, effectiveFacets, effectivePage
    )}`)
  }

  /**
  * Perform the actual API search
  */
  async function performSearch(searchParams) {
    // reset the scroll in case they scrolled down to read prior results
    window.scrollTo(0, 0)
    const results = await fetchSearch(
      'study', searchParams.terms, searchParams.facets, searchParams.page
    )
    setSearchState({
      params: searchParams,
      isError: false,
      isLoading: false,
      isLoaded: true,
      results,
      updateSearch
    })
  }

  if (
    !_isEqual(updatedParams, searchState.params) ||
    !searchState.isLoading && !searchState.isLoaded
  ) {
    performSearch(updatedParams)
    setSearchState({
      params: updatedParams,
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
