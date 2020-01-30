import React, { useState } from 'react';
import Button from 'react-bootstrap/Button';

import FacetsAccordion from './FacetsAccordion';

export default function FacetsAccordionBox(props) {
  
  const [canSave, setCanSave] = useState(false);

  // /**
  //  * Returns IDs of selected filters.
  //  * Enables comparing current vs. saved filters to enable/disable SAVE button
  //  */
  // function getCheckedFilterIDs() {
  //   const checkedSelector = `#facets-accordion-box input:checked`;
  //   const checkedFilterIDs =
  //     [...document.querySelectorAll(checkedSelector)].map((filter) => {
  //       return filter.id;
  //     });
  //   return checkedFilterIDs
  // }

  // function handleSaveClick(event) {
  //   const saveButtonClasses = Array.from(event.target.classList);
  
  //   if (saveButtonClasses.includes('disabled')) return;
    
  //   setSavedSelection(getCheckedFilterIDs());
  // };

  console.log('props.facets')
  console.log(props.facets)

  return (
    <div id='facets-accordion-box' style={{display: props.show ? '' : 'none'}}>
      <FacetsAccordion facets={props.facets} />
      {/* 
      Consider abstracting this and similar code block in
      FiltersBox into new SearchPanelBoxFooter component
       */}
      <Button
        id='save-more-filters'
        className={'facet-save-button ' + (canSave ? 'enabled' : 'disabled')}
        // onClick={handleSaveClick}
        >
        SAVE
      </Button>
    </div>
  );
}