import React, { useState, useEffect, useContext } from 'react'
import FacetControl from './FacetControl'
import MoreFacetsButton from './MoreFacetsButton'
import { SearchFacetContext } from './search/SearchFacetProvider'

export default function FacetsPanel() {
  const searchFacetContext = useContext(SearchFacetContext)

  return (
    <>
      {
        searchFacetContext.defaultFacets.map((facet, i) => {
          return <FacetControl facet={facet} key={i}/>
        })
      }
      <MoreFacetsButton facets={searchFacetContext.moreFacets} />
    </>
  ))
}
