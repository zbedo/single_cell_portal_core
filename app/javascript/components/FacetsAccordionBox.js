import React, { useEffect } from 'react';

import FacetsAccordion from './FacetsAccordion';

/**
 * Component for containing accordion of facets shown upon clicking "More Filters"
 *
 * UI spec: https://projects.invisionapp.com/d/main#/console/19272801/402387756/preview
 *
 * TODO:
 *  - Add angle icons
 */
export default function FacetsAccordionBox(props) {

  const componentId = 'facets-accordion-box';

  return (
    <div id={componentId} style={{display: props.show ? '' : 'none'}}>
      <FacetsAccordion
        facets={props.facets}
      />
    </div>
  );
}
