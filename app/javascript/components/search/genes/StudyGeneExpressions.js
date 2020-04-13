import React, { useState, useEffect, useContext } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons'

import { fetchExpressionViolin, fetchExpressionHeatmap, studyNameAsUrlParam } from 'lib/scp-api'
import { getByline } from 'components/search/results/Study'
import { UserContext } from 'providers/UserProvider'
import StudyGeneDotPlot from './StudyGeneDotPlot'
import StudyViolinPlot from './StudyViolinPlot'

export default function StudyGeneExpressions({ study }) {
  let studyRenderComponent
  if (study.gene_matches.length > 1) {
    studyRenderComponent = <StudyGeneDotPlot study={study} genes={study.gene_matches}/>
  } else {
    studyRenderComponent = <StudyViolinPlot study={study} gene={study.gene_matches[0]}/>
  }
  return (
    <div className="study-gene-result">
      <label htmlFor={study.name} id= 'result-title'>
        <a href={study.study_url} >{ study.name }</a>
      </label>
      <div ><em>{ getByline(study.description) }</em></div>
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
      { studyRenderComponent }
    </div>
  )
}

export function studyByline(study) {
  return study.description.substring()

}


