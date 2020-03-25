import React, { useContext, useState } from 'react'
import { fetchFacets } from 'lib/scp-api'

const defaultFacetIds = ['disease', 'organ', 'species', 'cell_type']
const moreFacetIds = [
  'sex', 'race', 'library_preparation_protocol', 'organism_age'
]

/*
 * this may evolve into something more sophisticated, or with actual
 * message keys, but for now it just converts snake case to word case
 * see https://broadworkbench.atlassian.net/browse/SCP-2108
 */
export function getDisplayNameForFacet(facetId) {
  return facetId.replace(/_/gi, ' ')
}

export const SearchFacetContext = React.createContext({
  defaultFacets: [],
  moreFacets: [],
  isLoading: false,
  isLoaded: false
})

export function useContextSearchFacet() {
  return useContext(SearchFacetContext)
}

export default function SearchFacetProvider(props) {
  const [facetState, setFacetState] = useState({
    defaultFacets: [],
    moreFacets: [],
    isLoading: false,
    isLoaded: false
  })
  async function updateFacets() {
    setFacetState({
      defaultFacets: [],
      moreFacets: [],
      isLoading: true,
      isLoaded: false
    })
    const facets = await fetchFacets()
    const df = facets.filter(facet => defaultFacetIds.includes(facet.id))
    const mf = facets.filter(facet => moreFacetIds.includes(facet.id))
    setFacetState({
      defaultFacets: df,
      moreFacets: mf,
      isLoading: false,
      isLoaded: true
    })
  }
  if (!facetState.isLoading && !facetState.isLoaded) {
    updateFacets()
  }
  return (
    <SearchFacetContext.Provider value={facetState}>
      { props.children }
    </SearchFacetContext.Provider>
  )
}
