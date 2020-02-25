import React from 'react';
import PanelGroup from 'react-bootstrap/lib/PanelGroup';
import Panel from 'react-bootstrap/lib/Panel';

import Filters from './Filters';

export default function FacetsAccordion(props) {
  return (
    // Accordions provide a way to restrict Card components to only open one at a time.
    // https://react-bootstrap.github.io/components/accordion/
    <PanelGroup accordion id="facets-accordion">
      {
        props.facets.map((facet, i) => {
          return (
            <Panel key={i} eventKey={i}>
              <Panel.Heading>
                <Panel.Title toggle>
                  {facet.name}
                </Panel.Title>
              </Panel.Heading>
              <Panel.Body collapsible>
                {/* <Filters facet={facet} /> */}
              </Panel.Body>
            </Panel>
          );
        })
      }
    </PanelGroup>
  );
}
