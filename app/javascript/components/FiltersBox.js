import React, { useState, useEffect } from 'react';
import Button from 'react-bootstrap/lib/Button';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faExternalLinkAlt } from '@fortawesome/free-solid-svg-icons';
import isEqual from 'lodash/isEqual';

import Filters from './Filters';
import FiltersSearchBar from './FiltersSearchBar';

/**
 * Component that can be clicked to unselect filters
 */
function ClearFilters(props) {
  return (
    <span
      id={`clear-filters-${props.facetId}`}
      className='clear-filters'
      style={{display: props.show ? '' : 'none'}}
      onClick={props.onClick}
    >
      CLEAR
    </span>
  );
}

/**
 * Component for filter search and filter lists, and related functionality
 */
export default function FiltersBox(props) {
  const [canApply, setCanApply] = useState(false);
  const [showClear, setShowClear] = useState(false);
  const [appliedSelection, setAppliedSelection] = useState([]);
  const [selection, setSelection] = useState([]);
  const [matchingFilters, setMatchingFilters] = useState([]);
  // const [show, setShow] = useState(props.show);

  // console.log('props.show', props.show)
  // console.log('show', show)

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
  const facetName = props.facet.name;
  const componentName = 'filters-box';
  const filtersboxId = `${componentName}-${props.facet.id}`;
  const applyId = `save-${filtersboxId}`;

  /**
   * Returns IDs of selected filters.
   * Enables comparing current vs. applied filters to enable/disable APPLY button
   */
  function getCheckedFilterIDs() {
    const checkedSelector = `#${filtersboxId} input:checked`;
    const checkedFilterIDs =
      [...document.querySelectorAll(checkedSelector)].map((filter) => {
        return filter.id;
      });
    return checkedFilterIDs
  }

  function updateSelections() {
    const checkedFilterIDs = getCheckedFilterIDs();
    setSelection(checkedFilterIDs);

    setShowClear(checkedFilterIDs.length > 0);
  }

  function handleApplyClick(event) {
    const saveButtonClasses = Array.from(event.target.classList);

    if (saveButtonClasses.includes('disabled')) return;

    setSavedSelection(getCheckedFilterIDs());
  };

  function clearFilters() {
    const checkedSelector = `#${filtersBoxID} input:checked`;
    document.querySelectorAll(checkedSelector).forEach((checkedInput) => {
      checkedInput.checked = false;
    });

    updateSelections();
  }

  // Search for filters in this facet that match input text terms
  //
  // For example, among the many filters in the "Disease" facet, search
  // for filters matching the term "tuberculosis".
  async function searchFilters(terms) {
    const apiData = await fetchFacetsFilters(props.facetId, terms);
    const matchingFilters = apiData.filters;
    setMatchingFilters(matchingFilters);
  }

  async function handleApply(event) {
    event.preventDefault();
    const terms = event.target.elements[filtersSearchBarId].value;
    await searchFilters(terms);
  }

  async function handleApplyButtonClick(event) {
    const terms = event.parentElement.parentElement.elements[filtersSearchBarID].value;
    await searchFilters(terms);
  }

  return (
    <div className={componentName} id={filtersboxId} style={{display: props.show ? '' : 'none'}}>
      <FiltersSearchBar filtersboxId={filtersboxId} facetId={props.facet.id} />
      <p className='filters-box-header'>
        <span className='default-filters-list-name'>FREQUENTLY SEARCHED</span>
        <span className='facet-ontology-links'>
          {
          props.facet.links.map((link, i) => {
            return (
              <a key={`link-${i}`} href={link.url} target='_blank'>
                {link.name}&nbsp;&nbsp;<FontAwesomeIcon icon={faExternalLinkAlt}/><br/>
              </a>
            );
          })
          }
        </span>
      </p>
      <ul>
        <Filters
          facetType='string'
          filters={props.facet.filters}
          onClick={updateSelections}
        />
      </ul>
      {/*
      TODO: abstracting this and similar code block in
      FacetsAccordionBox into new component (SCP-2109)
       */}
      <div className='filters-box-footer'>
        <ClearFilters
          show={showClear}
          facetId={props.facet.id}
          onClick={clearFilters}
        />
        <Button
          id={applyId}
          bsStyle='primary'
          className={'facet-apply-button ' + (canApply ? 'active' : 'disabled')}
          onClick={handleApplyClick}>
          APPLY
        </Button>
      </div>
    </div>
  );
}
