import React, { useState } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faExternalLinkAlt } from '@fortawesome/free-solid-svg-icons'
import pluralize from 'pluralize'

import { fetchFacetFilters } from 'lib/scp-api'
import FiltersBox from './FiltersBox'
import FiltersSearchBar from './FiltersSearchBar'

/**
 * Component for filter search and filter lists
 */
export default function FiltersBoxSearchable(props) {
  // State that is specific to FiltersBox
  const [matchingFilters, setMatchingFilters] = useState(props.facet.filters)
  const [hasFilterSearchResults, setHasFilterSearchResults] = useState(false)

  /*
   * TODO: Get opinions, perhaps move to a UI code style guide.
   *
   * Systematic, predictable IDs help UX research and UI development.
   *
   * Form of IDs: <general name> <specific name(s)>
   * General: All lowercase, specified in app code (e.g. 'apply-facet')
   * Specific: Cased as specified in API (e.g. 'species', 'NCBItaxon9606')
   *
   * UI code concatenates names in the ID.  Names in ID are hyphen-delimited.
   *
   * Examples:
   *   * apply-facet-species (for calls-to-action use ID: <action> <component>)
   *   * filter-species-NCBItaxon9606
   */
  const facetName = props.facet.name
  const facetId = props.facet.id
  const componentName = 'filters-box-searchable'
  const componentId = `${componentName}-${facetId}`

  /**
   * Search for filters in this facet that match input text terms
   *
   * For example, among the many filters in the "Disease" facet, search
   * for filters matching the term "tuberculosis".
   */
  async function searchFilters(terms) {
    const apiData = await fetchFacetFilters(props.facet.id, terms)
    const matchingFilters = apiData.filters
    const hasResults = apiData.query !== '' && matchingFilters.length > 0

    setHasFilterSearchResults(hasResults)

    setMatchingFilters(matchingFilters)
  }

  /**
   * Summarize filters, either default or
   */
  function getFiltersSummary() {
    let filtersSummary = 'TOP FILTERS'

    if (hasFilterSearchResults) {
      const numMatches = matchingFilters.length
      const resultsName = pluralize(facetName, numMatches)
      filtersSummary = `${numMatches} ${resultsName} found`
    }
    return filtersSummary
  }

  const showSearchBar = props.facet.links.length > 0

  return (
    <>
      {
        props.show && <div className={componentName} id={componentId}>
          { showSearchBar && (
            <>
              <div className='facet-ontology-links'>
                {
                  props.facet.links.map((link, i) => {
                    return (
                      <a
                        key={`link-${i}`}
                        href={link.url}
                        target='_blank'
                        rel='noopener noreferrer'
                      >
                        {link.name}&nbsp;&nbsp;
                        <FontAwesomeIcon icon={faExternalLinkAlt}/>
                      </a>
                    )
                  })
                }
              </div>
              <FiltersSearchBar
                filtersBoxId={componentId}
                searchFilters={searchFilters}
              />
              <p className='filters-box-header'>
                <span className='default-filters-list-name'>
                  {getFiltersSummary()}
                </span>
              </p>
            </>
          )}
          <FiltersBox
            facet={props.facet}
            filters={matchingFilters}
            setShow={props.setShow}
            selection={props.selection}
            setSelection={props.setSelection}
          />
        </div>
      }
    </>
  )
}
