import React, { useContext, useState, useEffect } from 'react'
import _clone from 'lodash/clone'
import { faPlusSquare, faMinusSquare } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'

import { GeneSearchContext } from 'providers/GeneSearchProvider'
import { hasSearchParams, StudySearchContext } from 'providers/StudySearchProvider'
import SearchPanel from 'components/search/controls/SearchPanel'
import StudyResultsPanel from 'components/search/results/ResultsPanel'
import SearchQueryDisplay from 'components/search/results/SearchQueryDisplay'
import GeneResultsPanel from './GeneResultsPanel'
import { FeatureFlagContext } from 'providers/FeatureFlagProvider'

/**
  * Renders a gene search control panel and the associated results
  * can also show study filter controls if the feature flag gene_study_filter is true
  */
export default function GeneSearchView() {
  const featureFlagState = useContext(FeatureFlagContext)
  const geneSearchState = useContext(GeneSearchContext)
  const studySearchState = useContext(StudySearchContext)
  const [genes, setGenes] = useState(_clone(geneSearchState.params.genes))
  const [showStudyControls, setShowStudyControls] = useState(hasSearchParams(studySearchState.params))

  /** handles a user submitting a gene search */
  function handleSubmit(event) {
    event.preventDefault()
    geneSearchState.updateSearch({ genes }, studySearchState, featureFlagState.gene_study_filter)
  }

  let resultsContent
  const showStudySearchResults = !geneSearchState.isLoaded &&
                                 !geneSearchState.isLoading &&
                                 !geneSearchState.isError
  if (showStudySearchResults) {
    // we haven't tried a gene search yet, just show studies
    resultsContent = <StudyResultsPanel/>
  } else {
    resultsContent = <GeneResultsPanel/>
  }

  let geneSearchPlaceholder = 'Search for genes across all studies'
  if (hasSearchParams(studySearchState.params) && featureFlagState.gene_study_filter) {
    geneSearchPlaceholder = 'Search for genes in the filtered studies';
  }

  useEffect(() => {
    // if a study  search isn't already happening, perform one
    if (showStudySearchResults &&
        !studySearchState.isLoading &&
        !studySearchState.isLoaded) {
      studySearchState.performSearch()
    }
  })

  return (
    <div>
      <div className="row">
        <div className="col-md-6 col-sm-12 col-xs-12">
          <form onSubmit={ handleSubmit }>
            <div className="input-group">
              <input type="text"
                className="form-control gene-search-input"
                value={genes}
                onChange={ e => setGenes(e.target.value) }
                placeholder={ geneSearchPlaceholder }/>
              <div className="input-group-btn">
                <button className="btn btn-info"
                        type="submit"
                        name="commit"
                        id="submit-gene-search">
                  <span className="fas fa-search"></span>
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
      { featureFlagState.gene_study_filter &&
        <div className="row gene-study-filter">
          <div className="col-md-2 text-right">
            Study Filter &nbsp;
            <FontAwesomeIcon icon={ showStudyControls ? faMinusSquare : faPlusSquare}
              className="action"
              onClick={() => {setShowStudyControls(!showStudyControls)} }/>

          </div>
          <div className="col-md-10">
            { showStudyControls &&
              <SearchPanel keywordPrompt="Filter studies by keyword"
                showCommonButtons={false}
                showDownloadButton={false}/> }
          </div>
        </div> }
      <div className="row">
        <div className="col-md-12">
          { resultsContent }
        </div>
        <div className="col-md-12">
          <div id="load-more-genes-target"></div>
        </div>
      </div>
    </div>
  )
}
