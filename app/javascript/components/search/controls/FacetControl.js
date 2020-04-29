import React, { useState, useEffect, useRef, useContext } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faTimesCircle } from '@fortawesome/free-solid-svg-icons'

import FiltersBoxSearchable from './FiltersBoxSearchable'
import { StudySearchContext } from 'providers/StudySearchProvider'
import { getDisplayNameForFacet } from 'providers/SearchFacetProvider'
import { SearchSelectionContext } from 'providers/SearchSelectionProvider'
import { withErrorBoundary } from 'lib/ErrorBoundary'
import useCloseableModal from 'hooks/closeableModal'

/**
 * Converts string value to lowercase, hyphen-delimited version
 * e.g. "Cell type" -> "cell-type"
 */
function slug(value) {
  return value.toLowerCase().replace(/ /g, '-')
}

/**
 * Button for facets, and associated functions
 */
function RawFacetControl(props) {
  const [showFilters, setShowFilters] = useState(false)

  const facetName = props.facet.name
  const facetId = `facet-${slug(facetName)}`
  const searchContext = useContext(StudySearchContext)
  const appliedSelection = searchContext.params.facets[props.facet.id]
  const selectionContext = useContext(SearchSelectionContext)
  let selection = []
  if (selectionContext.facets[props.facet.id]) {
    selection = selectionContext.facets[props.facet.id]
  }

  let selectedFilterString
  if (appliedSelection && appliedSelection.length) {
    const selectedFilters =
      props.facet.filters.filter(filter => appliedSelection.includes(filter.id))
    if (selectedFilters.length > 1) {
      selectedFilterString = `${facetName} (${selectedFilters.length})`
    } else if (selectedFilters.length === 1) {
      selectedFilterString = selectedFilters[0].name
    } else {
      // it's a numeric range filter
      selectedFilterString = `${getDisplayNameForFacet(props.facet.id)}:
                              ${appliedSelection[0]}-${appliedSelection[1]}
                              ${appliedSelection[2]}`
    }
  }

  /**
    * Clear the selection and update search results
    */
  function clearFacet() {
    selectionContext.updateFacet(props.facet.id, [], true)
  }

  const { node, clearNode, handleButtonClick } = useCloseableModal(showFilters, setShowFilters)

  let controlContent = getDisplayNameForFacet(props.facet.id)
  if (selectedFilterString) {
    controlContent =
      <>
        {selectedFilterString }
        <button
          ref={clearNode}
          className='facet-clear'
          onClick={ clearFacet }
        >
          <FontAwesomeIcon icon={faTimesCircle}/>
        </button>
      </>
  }

  return (
    <span ref={node}
      id={facetId}
      className={`facet ${showFilters ? 'active' : ''} ${selectedFilterString ? 'selected' : ''}`} // eslint-disable-line max-len
    >
      <a onClick={handleButtonClick}>
        { controlContent }
      </a>
      <FiltersBoxSearchable
        show={showFilters}
        facet={props.facet}
        setShow={setShowFilters}
        selection={selection}
        setSelection={selection =>
          selectionContext.updateFacet(props.facet.id, selection)
        }/>
    </span>
  )
}

const FacetControl = withErrorBoundary(RawFacetControl)
export default FacetControl
