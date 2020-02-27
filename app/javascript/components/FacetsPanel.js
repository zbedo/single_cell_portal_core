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

      const organismAgeMock = [{
        "name": "Organism Age",
        "id": "organism_age",
        "links": [],
        "type": "number",
        "max": "150",
        "min": "0",
        "unit": "years",
        "all_units": ["hours", "days", "weeks", "months", "years"]
      }];

      const mfWithAgeMock = [...mf, ...organismAgeMock];

      setDefaultFacets(df);
      setMoreFacets(mfWithAgeMock);
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
