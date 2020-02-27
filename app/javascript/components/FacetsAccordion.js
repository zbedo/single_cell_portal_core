import React from 'react';
import PanelGroup from 'react-bootstrap/lib/PanelGroup';
import Panel from 'react-bootstrap/lib/Panel';

import FiltersBox from './FiltersBox'

import {ApplyButton, ClearFilters, useApplyAndClear} from './ApplyAndClear';

export default function FacetsAccordion(props) {


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

  const componentId = `facets-accordion`

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
                <FiltersBox
                  facet={facet}
                  filters={facet.filters}
                />
              </Panel.Body>
            </Panel>
          );
        })
      }
    </PanelGroup>
  );
}
