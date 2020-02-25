import React, { useState, useEffect } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faExternalLinkAlt } from '@fortawesome/free-solid-svg-icons';
import isEqual from 'lodash/isEqual';
import pluralize from 'pluralize';

import { fetchFacetFilters } from 'lib/scp-api';
import Filters from './Filters';
import FiltersSearchBar from './FiltersSearchBar';
import {ApplyButton, ClearFilters, useApplyAndClear} from './ApplyAndClear';

/**
 * Component for filter search and filter lists
 */
export default function FiltersBox(props) {

  // State for reusable "APPLY" and "Clear" buttons.
  // This uses a custom hook to encapsulate reusable state code and functions.
  // The FacetsAccordionBox also uses this custom hook.
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

  // State that is specific to FiltersBox
  const [matchingFilters, setMatchingFilters] = useState(props.facet.filters);
  const [hasFilterSearchResults, setHasFilterSearchResults] = useState(false);

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
  const facetId = props.facet.id;
  const componentName = 'filters-box';
  const filtersBoxId = `${componentName}-${facetId}`;
  const applyId = `apply-${filtersBoxId}`;

  // Search for filters in this facet that match input text terms
  //
  // For example, among the many filters in the "Disease" facet, search
  // for filters matching the term "tuberculosis".
  async function searchFilters(terms) {
    const apiData = await fetchFacetFilters(props.facet.id, terms);
    const matchingFilters = apiData.filters;

    setHasFilterSearchResults(apiData.query !== '' && matchingFilters.length > 0);

    setMatchingFilters(matchingFilters);
  }

  function getFiltersSummary() {
    let filtersSummary = 'FREQUENTLY SEARCHED';

    if (hasFilterSearchResults) {
      const numMatches = matchingFilters.length;
      const resultsName = pluralize(facetName, numMatches);
      filtersSummary = `${numMatches} ${resultsName} found`;
    }
    return filtersSummary;
  }

  return (
    <div className={componentName} id={filtersBoxId} style={{display: props.show ? '' : 'none'}}>
      <FiltersSearchBar
        filtersBoxId={filtersBoxId}
        searchFilters={searchFilters}
      />
      <p className='filters-box-header'>
        <span className='default-filters-list-name'>
          {getFiltersSummary()}
        </span>
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
          facet={props.facet}
          filters={matchingFilters}
          onClick={() => {updateSelections(filtersBoxId)}}
        />
      </ul>
      {/*
      TODO: abstracting this and similar code block in
      FacetsAccordionBox into new component (SCP-2109)
       */}
      <div className='filters-box-footer'>
        {showClear &&
        <ClearFilters
          facetId={props.facet.id}
          onClick={() => {clearFilters(filtersBoxId)}}
        />
        }
        <ApplyButton
          id={applyId}
          className={'facet-apply-button ' + (canApply ? 'active' : 'disabled')}
          onClick={(event) => {handleApplyClick(event, facetId)}}></ApplyButton>
        />
      </div>
    </div>
  );
}
