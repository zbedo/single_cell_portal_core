import React from 'react'
import { faSearch } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'

export default function SearchQueryDisplay({terms, facets}) {
  const hasFacets = facets.length > 0
  const hasTerms = terms && terms.length > 0
  if (!hasFacets && !hasTerms) {
    return <></>
  }

  let facetsDisplay = <span></span>
  let termsDisplay = <span></span>

  function formattedJoinedList(itemTexts, itemClass, joinText) {
    return itemTexts.map((text, index) => {
        return (
          <span key={index}>
            <span className={itemClass}>{text}</span>
            { (index != itemTexts.length - 1) &&
              <span className="join-text">{joinText}</span>}
          </span>
        )
    })
  }

  if (hasFacets) {
    let FacetContainer = (props) => <>{props.children}</>
    if (hasTerms) {
      FacetContainer = (props) => <><span className="join-text"> AND </span>({props.children})</>
    }

    const facetElements = facets.map((facet, index) => {
      return (<span key={index}>
        (
          <span className="facet-name">{facet.id}: </span>
          { formattedJoinedList(facet.filters.map(filter => filter.name), 'filter-name', ' OR ')}
        )
        { (index != facets.length - 1) &&
          <span className="join-text"> AND </span>}
      </span>)
    })
    facetsDisplay = <FacetContainer>Metadata contains {facetElements}</FacetContainer>
  }
  if (hasTerms) {
    termsDisplay = (
      <span>Text contains (
        { formattedJoinedList(terms, 'search-term', ' OR ') }
      )</span>)
    if (hasFacets) {
      termsDisplay = <span>({termsDisplay})</span>
    }
  }
  return <div className="search-query"> <FontAwesomeIcon icon={faSearch} />: {termsDisplay}{facetsDisplay}</div>
}
