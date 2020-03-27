import React, { useContext } from 'react'

import KeywordSearch from './KeywordSearch'
import FacetsPanel from './FacetsPanel'
import DownloadButton from './DownloadButton'
import DownloadProvider from 'components/search/DownloadProvider'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import { getFlagValue } from 'lib/feature-flags'

function CommonSearchButtons() {
  const searchState = useContext(StudySearchContext)
  function handleClick(ordering) {
    searchState.updateSearch({order: ordering})
  }
  return (
    <>
      <span className="facet">
        <a onClick={ () => handleClick('popular') }>Most Popular</a>
      </span>
      <span className="facet">
        <a onClick={ () => handleClick('recent') }>Most Recent</a>
      </span>
    </>
  )
}

/**
 * Component for SCP faceted search UI
 */
export default function SearchPanel({showCommonButtons, keywordPrompt}) {
  // Note: This might become  a Higher-Order Component (HOC).
  // This search component is currently specific to the "Studies" tab, but
  // could possibly also enable search for "Genes" and "Cells" tabs.

  let searchButtons = <></>
  if (showCommonButtons !== false) {
    searchButtons = <CommonSearchButtons/>
  }
  if (getFlagValue('faceted_search')) {
    searchButtons = <FacetsPanel/>
  }
  return (
    <div id='search-panel'>
      <KeywordSearch keywordPrompt={keywordPrompt}/>
      { searchButtons }
      <DownloadProvider>
        <DownloadButton />
      </DownloadProvider>
    </div>
  )
}

