import React from 'react'

import KeywordSearch from './KeywordSearch'
import FacetsPanel from './FacetsPanel'
import DownloadButton from './DownloadButton'

/**
 * Component for SCP faceted search UI
 *
 * This is an entry point into React code from the traditional JS code
 * See related integration at /app/javascript/packs/application.js
 */
export default function SearchPanel(props) {
  // Note: This might become  a Higher-Order Component (HOC).
  // This search component is currently specific to the "Studies" tab, but
  // could possibly also enable search for "Genes" and "Cells" tabs.

  return (
    <div className='container-fluid' id='search-panel'>
      <KeywordSearch/>
      <FacetsPanel />
      <DownloadButton />
    </div>
  )
}

