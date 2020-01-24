import React from 'react';
import FiltersBox from './FiltersBox';

const facets = [{
  name: 'species',
  filters: [
    {'name': 'Human', 'id': 'NCBItaxon9606'},
    {'name': 'Mouse', 'id': 'NCBItaxon10090'},
    {'name': 'Cow', 'id': 'NCBItaxon5555'},
  ]
}];

function ScpSearchStudies() {
  return (
    <div className="ScpSearch">
      <span>A new SCP search UI for studies is under development!</span>
      <FiltersBox facet={facets[0]}/>
    </div>
  );
}

export default ScpSearchStudies;