import React from 'react';
import Facet from './Facet';

// Only for development!  We'll fetch data once API endpoints are available.
import {facetsResponseMock, searchFiltersResponseMock} from './FacetsMockData';
const facets = facetsResponseMock;

const defaultFacetIDs = ['disease', 'organ', 'species', 'cell_type'];
const moreFacetIDs = ['sex', 'race', 'library_preparation_protocol', 'organism_age'];

const defaultFacets = facets.filter(facet => defaultFacetIDs.includes(facet.id));
const moreFacets = facets.filter(facet => moreFacetIDs.includes(facet.id));

window.searchFiltersResponse = searchFiltersResponseMock;

function ScpSearchStudies() {
  return (
    <div>
      {
        defaultFacets.map((facet) => {
          return <Facet facet={facet} />
        })
      }
    </div>
    // <MoreFilters facets={moreFacets} />
  );
}

export default ScpSearchStudies;