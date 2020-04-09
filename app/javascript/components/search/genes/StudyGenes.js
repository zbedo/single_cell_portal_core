import React, { useState } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons'

import { fetchExpressionRender } from 'lib/scp-api'

/* displays a brief summary of a study, with a link to the study page */
export default function StudyGenes({ study }) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [clusterOptions, setClusterOptions] = useState([])
  const [annotationOptions, setAnnotationOptions] = useState({'Study Wide': [], 'Cluster-Based': []})
  const [subsamplingOptions, setSubsamplingOptions] = useState([])
  const [renderParams, setRenderParams] = useState({
    cluster: '',
    annotation: '',
    subsample: undefined
  })
  function parseResultsToArray(results) {
    const keys = Object.keys(results.values)
    return keys.map((key) => {
      return [key, results.values[key].y]
    })
  }

  function updateRenderParams(newParams) {
    const mergedParams = Object.assign({}, renderParams, newParams)
    loadGeneExpressionRender(mergedParams)
  }
  async function loadGeneExpressionRender(paramsToRender) {
    const results = await fetchExpressionRender(study.accession,
                                                study.gene_matches,
                                                paramsToRender.cluster,
                                                paramsToRender.annotation,
                                                paramsToRender.subsample)

    let dataArray = parseResultsToArray(results)
    const jitter = results.values_jitter ? results.values_jitter : undefined
    let traceData = window.createTracesAndLayout(dataArray, results.rendered_cluster, jitter, results.y_axis_title)
    const expressionData = [].concat.apply([], traceData[0] );
    const expressionLayout = traceData[1];
    setIsLoaded(true)
    setIsLoading(false)
    setClusterOptions(results.options)
    setAnnotationOptions(results.cluster_annotations)
    setSubsamplingOptions(results.subsampling_options)
    setRenderParams({
      cluster: results.rendered_cluster,
      annotation: results.rendered_annotation,
      subsample: results.rendered_subsample
    })
    window.Plotly.newPlot('expGraph' + study.accession, expressionData, expressionLayout);
  }
  if (!isLoaded && !isLoading) {
    loadGeneExpressionRender(renderParams)
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
          <div className="col-md-10 text-center">
            <br/>
            <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/>
          </div>
        }
        <div className="col-md-2">
          <div className="form-group">
            <label>Load cluster</label>
            <select className="form-control cluster-select global-gene-cluster"
                    value={renderParams.cluster}
                    onChange={event => { updateRenderParams({cluster: event.target.value})}}>
              { clusterOptions.map((opt, index) => {
                return <option key={index} value={opt}>{opt}</option>
              })}
            </select>
          </div>
          <div className="form-group">
            <label>Select annotation</label>
            <select className="form-control annotation-select global-gene-annotation"
                    value={renderParams.annotation}
                    onChange={event => { updateRenderParams({annotation: event.target.value})}}>
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
          { subsamplingOptions.length > 0 &&
            <div className="form-group">
              <label>Subsampling threshold</label>
              <select className="form-control subsample-select global-gene-subsample">
                { subsamplingOptions.map((opt, index) => {
                  return <option key={index} value={opt[1]}>{opt[0]}</option>
                })}
              </select>
            </div>
          }
        </div>
      </div>
    </div>
  )
}
