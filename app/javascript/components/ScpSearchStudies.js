import React from 'react';
import Facet from './Facet';

// Only for development!  We'll fetch data once API endpoints are available.
import {facetsResponseMock, searchFiltersResponseMock} from './FacetsMockData';
const facets = facetsResponseMock;

window.searchFiltersResponse = searchFiltersResponseMock;

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