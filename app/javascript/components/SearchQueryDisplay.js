import React from 'react'

export default function SearchQueryDisplay({terms, facets}) {
  const hasFacets = facets.length > 0
  const hasTerms = terms && terms.length > 0
  let facetsDisplay = <span></span>
  let termsDisplay = <span></span>
  if (hasFacets) {
    let FacetContainer = (props) => <>{props.children}</>
    if (hasTerms) {
      FacetContainer = (props) => <><span className="join-text"> AND </span>({props.children})</>
    }

    const facetElements = facets.map((facet, index) => {
      return (<span key={index}>
        (
          <span className="facet-name">{facet.id}: </span>
          {facet.filters.map((filter, filterIndex) => {
              return (
                <span key={filterIndex}>
                  <span className="filter-name">{filter.name}</span>
                  { (filterIndex != facet.filters.length - 1) &&
                    <span className="join-text"> OR </span>}
                </span>
              )
          })}
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
        {terms.map((term, index) => {
          return (
            <span key={index}>
              <span className="search-term">{term}</span>
              { (index != terms.length - 1) &&
                <span className="join-text"> OR </span>}
            </span>)
        })}
      )</span>)
    if (hasFacets) {
      termsDisplay = <span>({termsDisplay})</span>
    }
  }
  return <div className="search-query">Query: {termsDisplay}{facetsDisplay}</div>
}
