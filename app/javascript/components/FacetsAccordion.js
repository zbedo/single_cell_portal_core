import React, { useState } from 'react';
import PanelGroup from 'react-bootstrap/lib/PanelGroup';
import Panel from 'react-bootstrap/lib/Panel';

import FacetControl from './FacetControl'

export default function FacetsAccordion(props) {
  return (
    <PanelGroup accordion id='facets-accordion'>
      {
        props.facets.map((facet, i) => {
          return (
            <FacetControl facet={facet} key={i}/>
          );
        })
      }
    </PanelGroup>
  );
}
