import React, { Component, useState } from 'react';
import FiltersBox from './FiltersBox';

/**
 * Converts string value to lowercase, hyphen-delimited version
 * e.g. "Cell type" -> "cell-type"
 * @param {*} value 
 */
function slug(value) {
  return value.toLowerCase().replace('')
}

function Facet(props) {
  
  const [showFilters, setShowFilters] = useState(true);
  
  function handleClick(event) {
    setShowFilters(!showFilters);
    console.log('showFilters in handleClick:')
    console.log(showFilters)
  }

  const facetName = props.facet.name;

  return (
      <span 
        id={slug(facetName)}
        onClick={handleClick}>
        {facetName}
        <FiltersBox show={showFilters} facet={props.facet} />
      </span>
    );
  
}

export default Facet;