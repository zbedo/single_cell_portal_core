import React from 'react';
import Facet from './Facet';

// Only for development!  We'll fetch data once API endpoints are available.
import facetsMockData from './FacetsMockData';
const facets = facetsMockData;

function ScpSearchStudies() {
  return (
    <div>
      {
        facets.map((facet) => {
          return <Facet facet={facet} />
        })
      }
    </div>
  );
}

export default ScpSearchStudies;