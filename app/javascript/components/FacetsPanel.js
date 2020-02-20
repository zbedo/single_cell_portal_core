import React, { useState, useEffect } from 'react';
import FacetControl from './FacetControl';
import MoreFacetsButton from './MoreFacetsButton';

import { fetchFacets } from 'lib/scp-api';

const defaultFacetIds = ['disease', 'organ', 'species', 'cell_type'];
const moreFacetIds = ['sex', 'race', 'library_preparation_protocol', 'organism_age'];

export default function FacetsPanel() {
  const [defaultFacets, setDefaultFacets] = useState([]);
  const [moreFacets, setMoreFacets] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const facets = await fetchFacets();
      const df = facets.filter(facet => defaultFacetIds.includes(facet.id));
      const mf = facets.filter(facet => moreFacetIds.includes(facet.id));
      setDefaultFacets(df);
      setMoreFacets(mf);
    };
    fetchData();
  }, []);


  return (
    <>
      {
        defaultFacets.map((facet, i) => {
          return <FacetControl facet={facet} key={i}/>
        })
      }
      <MoreFacetsButton facets={moreFacets} />
    </>
  );
}
