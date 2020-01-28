import React, { Component, useState } from 'react';
import FiltersBox from './FiltersBox';

/**
 * Converts string value to lowercase, hyphen-delimited version
 * e.g. "Cell type" -> "cell-type"
 * @param {*} value 
 */
function slug(value) {
  return value.toLowerCase().replace(/ /g, '-');
}

function Facet(props) {
  
  const [showFilters, setShowFilters] = useState(false);
  
  function handleClick() {
    setShowFilters(!showFilters);
  }

  const facetName = props.facet.name;

  const style = {
    padding: '8px 16px',
    marginRight: '8px',
    borderRadius: '15px',
    border: '0.64px solid #4D72AA',
    boxSizing: 'border-box',
    color: '#4D72AA',
    fontWeight: '500',
    cursor: 'pointer'
  }

  return (
      <span 
        style={style}
        id={slug(facetName)}
        onClick={handleClick}>
        {facetName}
        <FiltersBox show={showFilters} facet={props.facet} />
      </span>
    );
  
}

export default Facet;