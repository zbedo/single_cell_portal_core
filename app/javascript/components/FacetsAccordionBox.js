import React, { useEffect } from 'react';
import isEqual from 'lodash/isEqual';

import FacetsAccordion from './FacetsAccordion';
import {ApplyButton, ClearFilters, useApplyAndClear} from './ApplyAndClear';

/**
 * Component for containing accordion of facets shown upon clicking "More Filters"
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387756/preview
 *
 * Polish to consider:
 *  - Add angle icons
 */
export default function FacetsAccordionBox(props) {

  // State for reusable "APPLY" and "Clear" buttons.
  // This uses a custom hook to encapsulate reusable state code and functions.
  // The FiltersBox component also uses this custom hook.
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

  const componentId = 'facets-accordion-box';

  return (
    <div id={componentId} style={{display: props.show ? '' : 'none'}}>
      <FacetsAccordion
        facets={props.facets}
        onApplyFilter={updateSelections}
      />
      <div className='facets-accordion-box-footer'>
        {showClear &&
        <ClearFilters
          facetId={props.facet.id}
          onClick={() => {clearFilters(componentId)}}
        />
        }
        <ApplyButton
          id={'apply-' + componentId}
          className={'facet-apply-button ' + (canApply ? 'active' : 'disabled')}
          onClick={(event) => {handleApplyClick(event, componentId, true)}}
        />
      </div>
    </div>
  );
}
