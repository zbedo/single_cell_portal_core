import React, { useContext, useState } from 'react';

import Button from 'react-bootstrap/lib/Button';

import { SearchContext } from './SearchPanel';

/**
 * Component that can be clicked to unselect filters
 */
export function ClearFilters(props) {
  return (
    <span
      id={`clear-filters-${props.facetId}`}
      className='clear-filters'
      onClick={props.onClick}
    >
      CLEAR
    </span>
  );
}

/**
 * Component for the "APPLY" button that can be clicked it to save selected
 * filters for the current facet or facet accordion.
 */
export function ApplyButton(props) {
  return (
    <Button
      id={props.id}
      bsStyle='primary'
      className={props.className}
      onClick={props.onClick}
    >
    APPLY
    </Button>
  );
}
/**
 * Custom hook for boxes that have "APPLY" and "Clear" for one or more
 * filter lists, e.g. FiltersBox or FacetsAccordionBox
 */
export function useApplyAndClear() {

  const searchContext = useContext(SearchContext);

  const [canApply, setCanApply] = useState(false);
  const [showClear, setShowClear] = useState(false);
  const [appliedSelection, setAppliedSelection] = useState([]);
  const [selection, setSelection] = useState([]);

  /**
   * Returns IDs of selected filters.
   * Enables comparing current vs. applied filters to enable/disable APPLY button
   */
  function getCheckedFilterIds(facetBoxId) {
    const checkedSelector = `#${facetBoxId} input:checked`;
    const checkedFilterIds =
      [...document.querySelectorAll(checkedSelector)].map((filter) => {
        return filter.id;
      });
    return checkedFilterIds
  }

  function updateSelections(facetBoxId) {
    const checkedFilterIds = getCheckedFilterIds(facetBoxId);
    setSelection(checkedFilterIds);
    setShowClear(checkedFilterIds.length > 0);
  }

  function handleApplyClick(event, facetId, isMultipleFacets=false) {
    const applyButtonClasses = Array.from(event.target.classList);

    if (applyButtonClasses.includes('disabled')) return;

    const checkedFilterIds = getCheckedFilterIds();

    if (checkedFilterIds.length > 0) {
      searchContext.facets[facetId] = checkedFilterIds.join(',');
    } else {
      delete searchContext.facets[facetId];
    }

    setAppliedSelection(checkedFilterIds);
  }

  function clearFilters(facetBoxId) {
    const checkedSelector = `#${facetBoxId} input:checked`;
    document.querySelectorAll(checkedSelector).forEach((checkedInput) => {
      checkedInput.checked = false;
    });

    updateSelections();
  }

  return {
    canApply, setCanApply,
    showClear, setShowClear,
    appliedSelection, setAppliedSelection,
    selection, setSelection,
    updateSelections,
    getCheckedFilterIds,
    handleApplyClick,
    clearFilters
  };
}
