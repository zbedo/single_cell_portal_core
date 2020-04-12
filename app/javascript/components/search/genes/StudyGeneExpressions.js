import React, { useState, useEffect } from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna, faExclamationCircle } from '@fortawesome/free-solid-svg-icons'

import { fetchExpressionViolin, fetchExpressionHeatmap, studyNameAsUrlParam } from 'lib/scp-api'
import { getByline } from 'components/search/results/Study'

export default function StudyGeneExpressions({ study }) {
  let StudyRenderComponent
  if (study.gene_matches.length > 1) {
    StudyRenderComponent = MultiGeneExpression
  } else {
    StudyRenderComponent = SingleGeneExpression
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
      <StudyRenderComponent study={ study }/>
    </div>
  )
}

export function MultiGeneExpression({ study }) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  async function loadData() {
    setIsLoading(true)
    if (study.gene_matches.length > 1) {
      const geneParam = study.gene_matches.join('+')
      window.renderMorpheus(
        `/single_cell/study/${study.accession}/${studyNameAsUrlParam(study.name)}/expression_query?search[genes]=${geneParam}&row_centered=&row_centered=&cluster=`,
        `/single_cell/study/${study.accession}/${studyNameAsUrlParam(study.name)}/annotation_query?cluster=&annotation=CLUSTER--group--study&request_user_token=`,
        'CLUSTER',
        'group',
        `#expGraph${study.accession}`,
        { name: "CLUSTER",
          type: "group",
          scope: "study",
          values: ["DG", "GABAergic", "CA1", "CA3", "Glia", "Ependymal", "CA2", "Non"]},
        '',
        450,
        'relative'
      )
      setIsLoaded(true)
      setIsLoading(false)
    }
  }
  useEffect(() => {
    if (!isLoading && !isLoaded) {
      loadData()
    }
  })
  return (
    <div className="row">
      <div className="col-md-12">
        <div className="expression-graph" id={ 'expGraph' + study.accession }></div>
        { isLoading && <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/> }
      </div>
    </div>
  )
}

export function studyByline(study) {
  return study.description.substring()

}




/* displays a brief summary of a study, with a link to the study page */
export function SingleGeneExpression({ study }) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [clusterOptions, setClusterOptions] = useState([])
  const [annotationOptions, setAnnotationOptions] = useState({'Study Wide': [], 'Cluster-Based': []})
  const [subsamplingOptions, setSubsamplingOptions] = useState([])
  const [renderParams, setRenderParams] = useState({
    userUpdated: false,
    cluster: '',
    annotation: '',
    subsample: ''
  })
  function parseResultsToArray(results) {
    const keys = Object.keys(results.values)
    return keys.map((key) => {
      return [key, results.values[key].y]
    })
  }

  function updateRenderParams(newParams) {
    const mergedParams = Object.assign({}, renderParams, newParams)
    mergedParams.userUpdated = true
    setRenderParams(mergedParams)
  }

  async function loadData(paramsToRender) {
    setIsLoading(true)
    const results = await fetchExpressionViolin(study.accession,
                                                study.gene_matches[0],
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
      userUpdated: false,
      cluster: results.rendered_cluster,
      annotation: results.rendered_annotation,
      subsample: results.rendered_subsample
    })
    window.Plotly.newPlot('expGraph' + study.accession, expressionData, expressionLayout);
  }

  useEffect(() => {
    // do a load from the server if this is the initial load or if parameters have been updated by the user
    // note we need the extra check because the renderParams will actually change after the first server load
    // as the server sends back the option lists and selected defaults
    if (!isLoading && !isLoaded || renderParams.userUpdated) {
      loadData(renderParams)
    }
  }, [renderParams.cluster, renderParams.annotation, renderParams.subsample])

  return (
    <div className="row">
      <div className="col-md-10">
        <div className="expression-graph" id={ 'expGraph' + study.accession }></div>
        { isLoading && <FontAwesomeIcon icon={faDna} className="gene-load-spinner"/> }
      </div>
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

        <div className="form-group">
          <label>Subsampling threshold</label>
          <select className="form-control subsample-select global-gene-subsample">
            <option key={999} value=''>All cells</option>
            { subsamplingOptions.map((opt, index) => {
              return <option key={index} value={opt}>{opt}</option>
            })}
          </select>
        </div>
      </div>
    </div>
  )
}
