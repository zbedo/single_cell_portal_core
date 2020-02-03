import React from 'react';

import FacetControl from './FacetControl';
import MoreFacetsButton from './MoreFacetsButton';
import DownloadButton from './DownloadButton';

// Only for development!  We'll fetch data once API endpoints are available.
import {facetsResponseMock, searchFiltersResponseMock} from './FacetsMockData';
const facets = facetsResponseMock;

const defaultFacetIDs = ['disease', 'organ', 'species', 'cell_type'];
const moreFacetIDs = ['sex', 'race', 'library_preparation_protocol', 'organism_age'];

const defaultFacets = facets.filter(facet => defaultFacetIDs.includes(facet.id));
const moreFacets = facets.filter(facet => moreFacetIDs.includes(facet.id));

window.searchFiltersResponse = searchFiltersResponseMock;

/**
 * Component for SCP advanced search UI
 *
 * This is the entry point into React code from the traditional JS code
 * See related integration at /app/javascript/packs/application.js
 */
function ScpSearchStudies() {
  return (
    <div id='search-panel'>
      {
        defaultFacets.map((facet) => {
          return <FacetControl facet={facet} />
        })
      }
      <MoreFacetsButton facets={moreFacets} />
      <DownloadButton />
    </div>
  );
}

export default ScpSearchStudies;
