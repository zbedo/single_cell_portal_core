import React, { useContext, useState, useEffect } from 'react';
import isEqual from 'lodash/isEqual';
import Button from 'react-bootstrap/lib/Button';

import Filters from './Filters';

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
 * Component for filter lists that have Apply and Clear
 */
export default function FiltersBox(props) {

  const searchContext = useContext(SearchContext);

  const [canApply, setCanApply] = useState(false);
  const [showClear, setShowClear] = useState(false);
  const [appliedSelection, setAppliedSelection] = useState([]);
  const [selection, setSelection] = useState([]);

  useEffect(() => {
    setCanApply(!isEqual(selection, appliedSelection));
  }, [selection]);

  useEffect(() => {
    setCanApply(false);
  }, [appliedSelection]);

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

  function handleApplyClick(event, facetId) {
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

  // TODO: Get opinions, perhaps move to a UI code style guide.
  //
  // Systematic, predictable IDs help UX research and UI development.
  //
  // Form of IDs: <general name> <specific name(s)>
  // General name: All lowercase, specified in app code (e.g. 'apply-facet', 'filter')
  // Specific name(s): Cased as specified in API (e.g. 'species', 'NCBItaxon9606')
  //
  // UI code concatenates names in the ID.  Names in ID are hyphen-delimited.
  //
  // Examples:
  //   * apply-facet-species (for calls-to-action use ID: <action> <component>)
  //   * filter-species-NCBItaxon9606
  const facetId = props.facet.id;
  const componentName = 'filters-box';
  const filtersBoxId = `${componentName}-${facetId}`;
  const applyId = `apply-${filtersBoxId}`;

  return (
    <div id={filtersBoxId}>
      <Filters
        facet={props.facet}
        filters={props.filters}
        onClick={() => {updateSelections(filtersBoxId)}}
      />
      <div className='filters-box-footer'>
        {showClear &&
        <ClearFilters
          facetId={props.facet.id}
          onClick={() => {clearFilters(filtersBoxId)}}
        />
        }
        <ApplyButton
          id={applyId}
          className={'facet-apply-button ' + (canApply ? 'active' : 'disabled')}
          onClick={(event) => {handleApplyClick(event, facetId)}}
        />
      </div>
    </div>
  );
}
