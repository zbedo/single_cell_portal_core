/* eslint-disable */
import React, { useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faSlidersH } from '@fortawesome/free-solid-svg-icons';

import FacetsAccordion from './FacetsAccordion';

/**
 * Component for "More Facets" button.  Clicking shows facets accordion box.
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387756/preview
 */
export default function MoreFacetsButton(props) {

  const [show, setShow] = useState(false);

  // const facetName = props.facet.name;

  function handleClick() {
    setShow(!show);
  }

  return (
      <span
        id='more-facets-button'
        className={`${show ? 'active' : ''} facet`}>
        <span
          onClick={handleClick}>
          <FontAwesomeIcon className="icon-left" icon={faSlidersH}/>
          More Facets
        </span>
        {show && <FacetsAccordion facets={props.facets} />}
      </span>
    );
}
