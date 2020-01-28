
const facetsMockData = [
  {
    name: 'Species',
    id: 'species',
    links: [{name: 'NCBI Taxonomy', url: 'https://foo.tdb'}],
    filters: [
      {name: 'human', id: 'NCBItaxon9606'},
      {name: 'mouse', id: 'NCBItaxon10090'},
      {name: 'cow', id: 'NCBItaxon5555'},
    ]
  },
  {
    name: 'Disease',
    id: 'disease',
    links: [
      {name: 'Disease ontology', url: 'https://bar.tdb'},
      {name: 'PATO ontology', url: 'https://pato.tdb'},
    ],
    filters: [
      {name: 'tubercolosis', id: 'DOID0000123'},
      {name: 'ocular tubercolosis', id: 'DOID0000124'},
      {name: 'tuberculosis, spinal', id: 'DOID0000125'},
      {name: 'endocrine tuberculosis', id: 'DOID0000126'},
      {name: 'inactive tuberculosis', id: 'DOID0000127'},
      {name: 'tubercolosis, bovine', id: 'DOID0000128'},
      {name: 'tuberculosis, avian', id: 'DOID0000129'},
      {name: 'esophageal tubercolosis', id: 'DOID0000130'},
      {name: 'intestinal tuberculosis', id: 'DOID0000131'},
      {name: 'abdominal tuberculosis', id: 'DOID0000132'},
    ]
  },
  {
    name: 'Organ',
    id: 'organ',
    links: [{name: 'UBERON', url: 'https://uberon.tbd'}],
    filters: [
      {name: 'brain', id: 'UBERON000123'},
      {name: 'heart', id: 'UBERON000124'},
      {name: 'skeletal muscle', id: 'UBERON000125'},
      {name: 'PBMC', id: 'UBERON000126'},
    ]
  }
];

export default facetsMockData;