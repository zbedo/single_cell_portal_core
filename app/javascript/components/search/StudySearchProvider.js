import React, { useContext } from 'react'
import { fetchSearch, fetchFacets, buildSearchQueryString, buildFacetsFromQueryString } from 'lib/scp-api'
import _cloneDeep from 'lodash/cloneDeep'
import _assign from 'lodash/assign'
import { Router, navigate } from '@reach/router'
import * as queryString from 'query-string'
/* eslint-disable */
/*
  This is a single component and paired context that manages both the facet data and the search params and data
*/

const defaultFacetIds = ['disease', 'organ', 'species', 'cell_type'];
const moreFacetIds = ['sex', 'race', 'library_preparation_protocol', 'organism_age'];

const emptySearch = {
  params: {
    terms: '',
    facets: {},
    page: 1
  },
  results: [],
  isLoaded: false,
  isError: false,
  defaultFacets: [],
  moreFacets: [],
  updateSearch: () => { throw new Error('You are trying to use this context outside of a Provider container') }
}

export const StudySearchContext = React.createContext(emptySearch)

export function useContextStudySearch() {
  return useContext(StudySearchContext)
}

export default class StudySearchProvider extends React.Component {
  constructor(props) {
    super(props)
    const queryParams = queryString.parse(window.location.search);
    let initialState = _cloneDeep(emptySearch)
    initialState.params = {
      page: queryParams.page ? queryParams.page : 1,
      terms: queryParams.terms ? queryParams.terms : '',
      facets: buildFacetsFromQueryString(queryParams.facets)
    }
    initialState.updateSearch = this.updateSearch
    this.state = initialState
  }

  updateFacets = async () => {
    const facets = await fetchFacets();
    const df = facets.filter(facet => defaultFacetIds.includes(facet.id));
    const mf = facets.filter(facet => moreFacetIds.includes(facet.id));
    this.setState({
      defaultFacets: df,
      moreFacets: mf
    })
  }

  componentDidMount() {
    this.updateSearch();
    this.updateFacets();
  }

  updateSearch = async (searchParams) => {
    const effectiveParams = Object.assign(this.state.params, searchParams)
    if (searchParams) {
      navigate('?' + buildSearchQueryString('study', effectiveParams.terms, effectiveParams.facets))
    }
    const results = await fetchSearch('study', effectiveParams.terms, effectiveParams.facets, effectiveParams.page)
    this.setState({
      params: effectiveParams,
      isError: false,
      isLoaded: true,
      results: results
    })
  }

  render() {
    let BaseRoute = () => (<div>{ this.props.children }</div>)
    return (
      <StudySearchContext.Provider value={this.state}>
        <Router>
          <BaseRoute path="/single_cell"/>
        </Router>
      </StudySearchContext.Provider>
    )
  }
}
