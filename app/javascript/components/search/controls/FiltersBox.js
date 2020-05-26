import React, { useContext } from 'react'
import _isEqual from 'lodash/isEqual'
import Button from 'react-bootstrap/lib/Button'

import { StudySearchContext } from 'providers/StudySearchProvider'
import { SearchSelectionContext } from 'providers/SearchSelectionProvider'
import Filters from './Filters'


// To consider: Get opinions, perhaps move to a UI code style guide.
//
// Systematic, predictable IDs help UX research and UI development.
//
// Form of IDs: <general name> <specific name(s)>
// General name: All lowercase, specified in app code (e.g. 'apply-facet')
// Specific name(s): Cased as specified in API (e.g. 'NCBITaxon_9606')
//
// UI code concatenates names in the ID.  Names in ID are hyphen-delimited.
//
// Examples:
//   * apply-facet-species (for calls-to-action use ID: <action> <component>)
//   * filter-species-NCBITaxon_9606

/**
 * Component that can be clicked to unselect filters
 */
function ClearFilters(props) {
  return (
    <span
      id={`clear-filters-${props.facetId}`}
      className='clear-filters'
      onClick={props.onClick}
    >
      CLEAR
    </span>
  )
}

/**
 * Component for the "APPLY" button that can be clicked it to save selected
 * filters for the current facet or facet accordion.
 */
function ApplyButton(props) {
  return (
    <Button
      id={props.id}
      bsStyle='primary'
      className={props.className}
      onClick={props.onClick}
    >
    APPLY
    </Button>
  )
}

/**
 * Component for filter lists that have Apply and Clear
 * We should revisit this structure if we ever have to add a
 * type of control besides filter list and slider
 * Currently, FiltersBox has to own a lot of logic about canApply and applyClick
 * handling that is probably better encapsulated in the individual controls
 */
export default function FiltersBox({facet, selection, setSelection, filters, setShow, hideApply}) {
  const searchContext = useContext(StudySearchContext)
  const selectionContext = useContext(SearchSelectionContext)

  let appliedSelection = searchContext.params.facets[facet.id]
  appliedSelection = appliedSelection ? appliedSelection : []

  const showClear = selection.length > 0
  const isSelectionValid = facet.type != 'number' ||
                             (selection.length === 0 ||
                              !isNaN(parseInt(selection[0])) && !isNaN(parseInt(selection[1])))

  const canApply = isSelectionValid &&
                   (!_isEqual(selection, appliedSelection) ||
                   facet.type === 'number' && appliedSelection.length === 0)
                   // allow application of number filters to default range

  const facetId = facet.id
  const componentName = 'filters-box'
  const filtersBoxId = `${componentName}-${facetId}`
  const applyId = `apply-${filtersBoxId}`

  /**
   * Update search context with applied facets upon clicking "Apply"
   */
  function handleApplyClick() {
    if (!canApply) return
    if (facet.type === 'number' &&
        appliedSelection.length === 0 &&
        selection.length === 0) {
      // case where a user clicks apply without changing the slider
      const defaultSelection = [
        facet.min,
        facet.max,
        facet.unit
      ]
      selectionContext.updateFacet(facet.id, defaultSelection, true)
    } else {
      selectionContext.performSearch()
    }
    if (setShow) {
      setShow(false)
    }
  }

  function clearFilters() {
    setSelection([])
  }

  return (
    <div id={filtersBoxId}>
      <Filters
        facet={facet}
        filters={filters}
        selection={selection}
        setSelection={setSelection}
      />
      <div className='filters-box-footer'>
        {showClear &&
        <ClearFilters
          facetId={facet.id}
          onClick={clearFilters}
        />
        }
        {!hideApply &&
          <ApplyButton
          id={applyId}
          className={`facet-apply-button ${canApply ? 'active' : 'disabled'}`}
          onClick={handleApplyClick}
          />
        }
      </div>
    </div>
  )
}
