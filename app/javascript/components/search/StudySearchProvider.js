import React from 'react'
import { fetchSearch } from 'lib/scp-api'
import _cloneDeep from 'lodash/cloneDeep'
import _assign from 'lodash/assign'

const emptySearch = {
  params: {
    terms: '',
    facets: {}
  },
  results: [],
  isLoaded: false,
  isError: false,
  updateSearch: () => { throw new Error('You are trying to use this context outside of a Provider container') }
}

export const StudySearchContext = React.createContext(emptySearch)

export default class StudySearchProvider extends React.Component {
  constructor(props) {
    super(props)
    let initialState = _cloneDeep(emptySearch)
    initialState.updateSearch = this.updateSearch
    this.state = initialState
  }

  componentDidMount() {
    this.updateSearch();
  }

  updateSearch = async (searchParams) => {
    const effectiveParams = _assign(this.state.params, searchParams)
    const results = await fetchSearch('study', effectiveParams.terms, effectiveParams.facets)
    this.setState({
      params: effectiveParams,
      isError: false,
      isLoaded: true,
      results: results
    })
  }

  render() {
    return (
      <StudySearchContext.Provider value={this.state}>
        { this.props.children }
      </StudySearchContext.Provider>
    )
  }
}
