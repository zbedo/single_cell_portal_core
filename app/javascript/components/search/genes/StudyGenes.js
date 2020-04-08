import React, { useState } from 'react'

import { fetchExpressionRender } from 'lib/scp-api'

/* displays a brief summary of a study, with a link to the study page */
export default function StudyGenes({ study }) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [clusterOptions, setClusterOptions] = useState([])
  const [annotationOptions, setAnnotationOptions] = useState({'Study Wide': [], 'Cluster-Based': []})
  const [subsamplingOptions, setSubsamplingOptions] = useState([])
  function parseResultsToArray(results) {
    const keys = Object.keys(results.values)
    return keys.map((key) => {
      return [key, results.values[key].y]
    })
  }
  function loadStudyGenes(accession, studyName, genes) {
    fetchExpressionRender(accession, genes).then((results) => {
      let dataArray = parseResultsToArray(results)
      let traceData = window.createTracesAndLayout(dataArray)
      const expressionData = [].concat.apply([], traceData[0] );
      const expressionLayout = traceData[1];
      setIsLoaded(true)
      setIsLoading(false)
      setClusterOptions(results.options)
      setAnnotationOptions(results.cluster_annotations)
      window.Plotly.newPlot('expGraph' + accession, expressionData, expressionLayout);
    })
  }
  if (!isLoaded && !isLoading) {
    loadStudyGenes(study.accession, study.name, study.gene_matches)
    setIsLoading(true)
  }
  return (
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
      <div className="row">
        { isLoaded &&
          <div className="col-md-10">
            <div className="expression-graph" id={ 'expGraph' + study.accession }></div>
          </div>
        }
        { !isLoaded &&
          <div className="col-md-10">
            <span className="fa fa-spin">Loading</span>
          </div>
        }
        <div className="col-md-2">
          <div className="form-group">
            <label>Load cluster</label>
            <select className="form-control cluster-select global-gene-cluster">
              { clusterOptions.map((opt, index) => {
                return <option key={index} value={opt}>{opt}</option>
              })}
            </select>
          </div>
          <div className="form-group">
            <label>Select annotation</label>
            <select className="form-control annotation-select global-gene-annotation">
              <optgroup label="Study Wide">
                { annotationOptions['Study Wide'].map((opt, index) => {
                  return <option key={index} value={opt[1]}>{opt[0]}</option>
                })}
              </optgroup>
              <optgroup label="Cluster-Based">
                { annotationOptions['Cluster-Based'].map((opt, index) => {
                  return <option key={index} value={opt[1]}>{opt[0]}</option>
                })}
              </optgroup>
            </select>
          </div>
          <div className="form-group">
            <label>Subsampling threshold</label>
            <select className="form-control subsample-select global-gene-subsample">
              { subsamplingOptions.map((opt, index) => {
                return <option key={index} value={opt[1]}>{opt[0]}</option>
              })}
            </select>
          </div>
        </div>
      </div>
    </div>
  )
}
