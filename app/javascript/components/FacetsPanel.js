import React, { useState, useEffect, useContext } from 'react';
import FacetControl from './FacetControl';
import MoreFacetsButton from './MoreFacetsButton';
import { StudySearchContext } from 'components/search/StudySearchProvider'


export default function FacetsPanel() {
  const searchContext = useContext(StudySearchContext)

  return (
    <>
      {
        searchContext.defaultFacets.map((facet, i) => {
          return <FacetControl facet={facet} key={i}/>
        })
      }
      <MoreFacetsButton facets={searchContext.moreFacets} />
    </>
  );
}
