import React, { useContext, useState, useEffect } from 'react'
import _clone from 'lodash/clone'
import { faPlusSquare, faMinusSquare } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'

import { GeneSearchContext } from 'providers/GeneSearchProvider'
import { hasSearchParams, StudySearchContext } from 'providers/StudySearchProvider'
import SearchPanel from 'components/search/controls/SearchPanel'
import StudyResultsPanel from 'components/search/results/ResultsPanel'
import SearchQueryDisplay from 'components/search/results/SearchQueryDisplay'

export default function GeneSearchView() {
  const geneSearchState = useContext(GeneSearchContext)
  const studySearchState = useContext(StudySearchContext)
  let [genes, setGenes] = useState(_clone(geneSearchState.params.genes))
  const [showStudyControls, setShowStudyControls] = useState(hasSearchParams(studySearchState.params))
  function handleSubmit(event) {
    event.preventDefault()
    geneSearchState.updateSearch({genes: genes}, studySearchState)
  }


  let studyFilterText = <div></div>
  if (studySearchState.results.totalStudies) {
    studyFilterText = <div>
      <SearchQueryDisplay terms={studySearchState.results.termList} facets={studySearchState.results.facets}/>
    </div>
  }

  let resultsContent
  const showStudySearchResults = !geneSearchState.isLoaded && !geneSearchState.isLoading && !geneSearchState.isError
  if (showStudySearchResults) {
    // we haven't tried a gene search yet, just show studies
    resultsContent = <StudyResultsPanel/>
  } else {
    resultsContent = <div> Look at all these genes!!!</div>
  }

  const geneSearchPlaceholder = hasSearchParams(studySearchState.params)
                              ? "Search for genes in the filtered studies"
                              : "Search for genes across all studies"

  useEffect(() => {
    // if a study  search isn't already happening, perform one
    if (showStudySearchResults && !studySearchState.isLoading && !studySearchState.isLoaded) {
      studySearchState.performSearch()
    }
  })

  return (
    <div>
      <div className="row">
        <div className="col-md-6 col-sm-12 col-xs-12">
          <form onSubmit={ handleSubmit }>
            <div className="input-group">
              <input type="text"
                     className="form-control "
                     value={genes}
                     onChange={ (e) => setGenes(e.target.value) }
                     placeholder={ geneSearchPlaceholder }/>
              <div className="input-group-btn">
                <button className="btn btn-info" type="submit" name="commit" id="submit-gene-search"><span className="fas fa-search"></span></button>
              </div>
            </div>
          </form>
        </div>
      </div>
      <div className="row gene-study-filter">
        <div className="col-md-2 text-right">
          Study Filter &nbsp;
          <FontAwesomeIcon icon={ showStudyControls ? faMinusSquare : faPlusSquare}
                           className="action"
                           onClick={()=>{setShowStudyControls(!showStudyControls)}}/>

        </div>
        <div className="col-md-10">
          { showStudyControls &&
            <SearchPanel keywordPrompt="Filter studies by keyword"
                         showCommonButtons={false}
                         showDownloadButton={false}/> }
        </div>
      </div>
      <div className="row">

      </div>
      <div className="row">
        <div className="col-md-12">
          { resultsContent }
        </div>
        <div className="col-md-12">
          <div id="load-more-genes-target"></div>
        </div>
      </div>
    </div>
  )
}

    // $('#submit-gene-search').on('click', function() {
    //     if ( $('#search_genes').val() === '' ) {
    //         alert('Please enter a term before searching.');
    //         return false;
    //     } else {
    //         window.GLOBAL_GENE_SEARCH_RESULTS = {};
    //         $('#page').val('1');
    //         $("#gene-search-results").empty();
    //         $('#gene-search-results-count').html($('div.gene-panel').length);
    //         $('#gene-search-studies-count').html($('div.has-gene-results').length);
    //         var target = document.getElementById('wrap');
    //         var spinner = new Spinner(opts).spin(target);
    //         $(target).data('spinner', spinner);
    //         var requestUrl = '<%= javascript_safe_url(search_all_genes_path) %>';
    //         var genes = $('#search_genes').val().split(' ');
    //         var numGenes = genes.length;
    //         // limit number of genes to MAX_GENE_SEARCH
    //         if (numGenes > <%= Gene::MAX_GENE_SEARCH %>) {
    //             console.log('Too many genes, limiting global gene search');
    //             alert('<%= Gene::MAX_GENE_SEARCH_MSG %>');
    //             genes = genes.slice(0, <%= Gene::MAX_GENE_SEARCH %>);
    //             numGenes = genes.length;
    //             $('#search_genes').val(genes.join(' '));
    //         }
    //         requestUrl += '?genes=' + genes.join('+') + '&num_genes=' + numGenes;
    //         gaTrack(requestUrl, 'Single Cell Portal | Global Gene Search');
    //         ga('send', 'event', 'engaged_user_action', 'global_gene_search');
    //         return true;
    //     }
    // });

    // function renderDistribution(identifier) {
    //     var studyAttr = window.GLOBAL_GENE_SEARCH_RESULTS[identifier];
    //     var geneExpUrl = studyAttr.renderUrl;
    //     var targetPlot = document.getElementById(identifier + '-plot');
    //     var geneId = studyAttr.geneId;

    //     $(targetPlot).data('rendered', false);
    //     // no need to store spinners in data attribute as entire plot div will be re-rendered
    //     new Spinner(opts).spin(targetPlot);

    //     var cluster = $('#' + identifier + '-cluster').val();
    //     var annotation = $('#' + identifier + '-annotation').val();
    //     var subsample = $('#' + identifier + '-subsample').val();
    //     geneExpUrl += '?cluster=' + encodeURIComponent(cluster) + '&annotation=' + encodeURIComponent(annotation) +
    //     '&subsample=' + subsample + '&identifier=' + geneId;
    //     // append request token to validate XHR requests
    //     var requestToken = '<%= user_signed_in? ? current_user.id.to_s + ':' + current_user.authentication_token : nil %>';
    //     geneExpUrl += '&request_user_token=' + requestToken;

    //     // make call to load distribution plot
    //     $.ajax({
    //         url: geneExpUrl,
    //         method: 'GET',
    //         dataType: 'script'
    //     });
    // }

    // // listener for cluster nav, specific to study page
    // $('#gene-search-results').on('change', '.global-gene-annotation, global-gene-subsample', function () {
    //     var identifier = extractIdentifierFromId($(this).attr('id'));
    //     renderDistribution(identifier);
    // });

    // $('#gene-search-results').on('change', '.global-gene-cluster', function() {
    //     var newCluster = $(this).val();
    //     var identifier = extractIdentifierFromId($(this).attr('id'));
    //     var annotUrl = window.GLOBAL_GENE_SEARCH_RESULTS[identifier].annotationUrl;
    //     var that = $(this); // store original context
    //     // get new annotation options and re-render
    //     $.ajax({
    //         url: annotUrl + "?cluster=" + encodeURIComponent(newCluster) + '&target=' + identifier,
    //         method: 'GET',
    //         dataType: 'script',
    //         complete: function (jqXHR, textStatus) {
    //             var callback = $.proxy(renderDistribution, that, identifier);
    //             renderWithNewCluster(textStatus, callback, false);
    //         }
    //     });
    // });
