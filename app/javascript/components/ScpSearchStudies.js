import React from 'react';
import Facet from './Facet';

const facets = [
  {
    name: 'Species',
    link: {name: 'NCBI Taxonomy', url: 'https://foo.tdb'},
    filters: [
      {name: 'Human', id: 'NCBItaxon9606'},
      {name: 'Mouse', id: 'NCBItaxon10090'},
      {name: 'Cow', id: 'NCBItaxon5555'},
    ]
  },
  {
    name: 'Disease',
    link: {name: 'Disease ontology', url: 'https://bar.tdb'},
    filters: [
      {name: 'tubercolosis', id: 'DOID0000123'},
      {name: 'ocular tubercolosis', id: 'DOID0000123'},
      {name: 'tuberculosis, spinal', id: 'DOID0000123'},
      {name: 'endocrine tuberculosis', id: 'DOID0000123'},
      {name: 'inactive tuberculosis', id: 'DOID0000123'},
      {name: 'tubercolosis, bovine', id: 'DOID0000123'},
      {name: 'tuberculosis, avian', id: 'DOID0000123'},
      {name: 'esophageal tubercolosis', id: 'DOID0000123'},
      {name: 'intestinal tuberculosis', id: 'DOID0000123'},
      {name: 'abdominal tuberculosis', id: 'DOID0000123'},
    ]
  }
];

function ScpSearchStudies() {
  return (
    <div>
      {
        facets.map((facet) => {
          return <Facet facet={facet} />
        })
      }
    </div>
  );
}

export default ScpSearchStudies;