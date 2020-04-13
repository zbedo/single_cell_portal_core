import React, {useState, useContext, useEffect} from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faDna } from '@fortawesome/free-solid-svg-icons'

import { studyNameAsUrlParam } from 'lib/scp-api'
import { UserContext } from 'providers/UserProvider'

export default function StudyGeneDotPlot({ study, genes }) {
  const userState = useContext(UserContext)
  const [isLoaded, setIsLoaded] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  async function loadData() {
    setIsLoading(true)
    if (study.gene_matches.length > 1) {
      const geneParam = genes.join('+')
      window.renderMorpheusDotPlot(
        `/single_cell/study/${study.accession}/${studyNameAsUrlParam(study.name)}/expression_query?search[genes]=${geneParam}&row_centered=&row_centered=&cluster=&request_user_token=${userState.accessToken}`,
        `/single_cell/study/${study.accession}/${studyNameAsUrlParam(study.name)}/annotation_query?cluster=&annotation=CLUSTER--group--study&request_user_token=${userState.accessToken}`,
        'CLUSTER',
        'group',
        `#expGraph${study.accession}`,
        study.annotations,
        '',
        450,
        `#expGraph${study.accession}-legend`,
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
