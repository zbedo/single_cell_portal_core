import React, { useState } from 'react';
import { Slider, Rail, Handles, Tracks, Ticks } from "react-compound-slider";
import InputGroup from 'react-bootstrap/InputGroup';

function FilterList(props) {
  return (
    <ul>
    {
      props.facet.filters.map((filter) => {
        return (
          <li key={'li-' + filter.id}>
            <InputGroup.Checkbox
              id={filter.id}
              aria-label="Checkbox"
              name={filter.id}
            />
            <label htmlFor={filter.id}>{filter.name}</label>
          </li>
        );
      })
    }
    </ul>
  );
}

function FilterSlider(props) {
  const facet = props.facet;
  // React Compound Slider
  // API: https://react-compound-slider.netlify.com/docs
  // Examples: https://react-compound-slider.netlify.com/horizontal
  return (
    <li>
      <Slider
        domain={[facet.min, facet.max]}
      />
    </li>
  );
}

export default function Filters(props) {
  const facet = props.facet;
  if (facet.type === 'string') {
    return <FilterList facet={facet} />;
  } else {
    return <FilterSlider facet={facet} />;
  }
}
