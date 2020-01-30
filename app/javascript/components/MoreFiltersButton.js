import React, { useState } from 'react';

import FacetsAccordionBox from './FacetsAccordionBox';

export default function MoreFiltersButton(props) {
  
  const [show, setShow] = useState(false);

  console.log('in MoreFiltersButton  props.facets')
  console.log(props.facets)
  
  // const facetName = props.facet.name;

  function handleClick() {
    setShow(!show);
  }

  return (
      <span
        id='more-filters-button'
        className={`${show ? 'active' : ''}`}>
        <span
          onClick={handleClick}>
          More filters
        </span>
        <FacetsAccordionBox show={show} facets={props.facets} />
      </span>
    );
}