import React, { useState, useEffect } from 'react';
import isEqual from 'lodash/isEqual';

import Filters from './Filters';
import {ApplyButton, ClearFilters, useApplyAndClear} from './ApplyAndClear';

/**
 * Component for filter lists that have Apply and Clear
 */
export default function FiltersBox(props) {

  // State for reusable "APPLY" and "Clear" buttons.
  // This uses a custom hook to encapsulate reusable state code and functions.
  // The FacetsAccordionBox also uses this custom hook.
  // It's like a Higher-Order Component, but for function components.
  const {
    canApply, setCanApply,
    showClear,
    appliedSelection,
    selection,
    updateSelections,
    handleApplyClick,
    clearFilters
  } = useApplyAndClear();

  useEffect(() => {
    setCanApply(!isEqual(selection, appliedSelection));
  }, [selection]);

  useEffect(() => {
    setCanApply(false);
  }, [appliedSelection]);

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
