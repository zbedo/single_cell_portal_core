import React from 'react'

import KeywordSearch from './KeywordSearch'
import FacetsPanel from './FacetsPanel'
import DownloadButton from './DownloadButton'
import DownloadProvider from 'components/search/DownloadProvider'

/**
 * Component for SCP faceted search UI
 */
export default function SearchPanel() {
  // Note: This might become  a Higher-Order Component (HOC).
  // This search component is currently specific to the "Studies" tab, but
  // could possibly also enable search for "Genes" and "Cells" tabs.

  return (
    <div className='container-fluid' id='search-panel'>
      <KeywordSearch/>
      <FacetsPanel/>
      <DownloadProvider>
        <DownloadButton />
      </DownloadProvider>
    </div>
  )
}

