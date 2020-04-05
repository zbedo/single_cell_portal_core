/* eslint-disable require-jsdoc */
import React from 'react'

/* displays a brief summary of a study, with a link to the study page */
export default function StudyGenes({ study }) {
  function loadStudyGenes(studyId, genes) {
    const geneParam = encodeURIComponent(genes.join(','))
    fetch(`/single_cell/api/v1/studies/${studyId}/genes?genes=${geneParam}`).then((results) => {


    })
  }
  return (
    <>
      <div key={study.accession}>
        <label htmlFor={study.name} id= 'result-title'>
          <a href={study.study_url} >{ study.name }</a>
        </label>
        <div>
          <span className='badge badge-secondary cell-count'>
            {study.cell_count} Cells
          </span>
          {
            study.gene_matches.map(geneName => {
              return (<span key={ geneName } className='badge gene-match'>
                { geneName }
              </span>)
            })
          }
        </div>
        <div>
          <a href="#" onClick={ () => loadStudyGenes(study.accession, study.gene_matches) }>Load me</a>
        </div>
      </div>
    </>
  )
}
