import React, { useContext } from 'react';

import KeywordSearch from './KeywordSearch';
import FacetsPanel from './FacetsPanel';
import DownloadButton from './DownloadButton';


const searchContexts = {
  study: {
    terms: '',
    facets: {}
  },
  genes: {
    // Stub
  },
  cells: {
    // Stub
  }
}

export const SearchContext = React.createContext(searchContexts.study);

/**
 * Component for SCP faceted search UI
 *
 * This is the entry point into React code from the traditional JS code
 * See related integration at /app/javascript/packs/application.js
 */
export default function SearchPanel() {
  // Note: This might become  a Higher-Order Component (HOC).
  // This search component is currently specific to the "Studies" tab, but
  // could possibly also enable search for "Genes" and "Cells" tabs.

  return (
    <SearchContext.Provider value={searchContexts.study}>
      <div className='container-fluid' id='search-panel'>
        {/* <KeywordSearch /> TODO: Uncomment before opening PR */}
        <FacetsPanel />
        <DownloadButton />
      </div>
    </SearchContext.Provider>
  );
}
