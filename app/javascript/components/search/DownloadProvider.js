import React, { useContext, useState } from 'react'
import { useContextStudySearch, hasSearchParams } from './StudySearchProvider'

import { fetchDownloadSize } from './../../lib/scp-api'

export const DownloadContext = React.createContext({
  searchResults: {},
  downloadSize: {}
})

/** Wrapper for deep mocking via Jest / Enzyme */
export function useContextDownload(props) {
  DownloadContext.searchResults = props.results
  return useContext(DownloadContext)
}

/** Provides loading status and fetched data for Bulk Download components */
export default function DownloadProvider(props) {
  const studyContext = useContextStudySearch()

  const [downloadState, setDownloadState] = useState({
    searchResults: props.results,
    downloadSize: {},
    isLoaded: false
  })

  /** Update size preview for bulk download */
  async function updateDownloadSize(results) {
    const accessions = results.matchingAccessions
    const fileTypes = ['Expression', 'Metadata']
    const size = await fetchDownloadSize(accessions, fileTypes)

    setDownloadState({
      isLoaded: true,
      downloadSize: size
    })
  }

  if (
    !studyContext.isLoading && studyContext.isLoaded &&
    !downloadState.isLoaded &&
    hasSearchParams(studyContext.params)
  ) {
    updateDownloadSize(studyContext.results)
  }

  return (
    <DownloadContext.Provider value={downloadState}>
      { props.children }
    </DownloadContext.Provider>
  )
}
