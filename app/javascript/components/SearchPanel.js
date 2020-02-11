import React, { useState, useEffect } from 'react';

import FacetControl from './FacetControl';
import MoreFacetsButton from './MoreFacetsButton';
import DownloadButton from './DownloadButton';

import { fetchFacets } from './../lib/scp-api';

const defaultFacetIDs = ['disease', 'organ', 'species', 'cell_type'];
const moreFacetIDs = ['sex', 'race', 'library_preparation_protocol', 'organism_age'];

/**
 * Component for SCP advanced search UI
 *
 * This is the entry point into React code from the traditional JS code
 * See related integration at /app/javascript/packs/application.js
 */
export default function SearchPanel() {

  const [defaultFacets, setDefaultFacets] = useState([]);
  const [moreFacets, setMoreFacets] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const facets = await fetchFacets(true);
      const df = facets.filter(facet => defaultFacetIDs.includes(facet.id));
      const mf = facets.filter(facet => moreFacetIDs.includes(facet.id));
      setDefaultFacets(df);
      setMoreFacets(mf);
    };
    fetchData();
  }, []);

  return (
    <div id='search-panel'>
      {
        defaultFacets.map((facet, i) => {
          return <FacetControl facet={facet} key={i}/>
        })
      }
      <MoreFacetsButton facets={moreFacets} />
      <DownloadButton />
    </div>
  );
}
