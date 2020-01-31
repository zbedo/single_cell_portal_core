import React, { useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faSlidersH } from '@fortawesome/free-solid-svg-icons';

import FacetsAccordionBox from './FacetsAccordionBox';

export default function MoreFiltersButton(props) {
  
  const [show, setShow] = useState(false);
  
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
          <FontAwesomeIcon className="icon-left" icon={faSlidersH}/>
          More Filters
        </span>
        <FacetsAccordionBox show={show} facets={props.facets} />
      </span>
    );
}