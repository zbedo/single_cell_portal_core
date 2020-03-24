import React, { useContext, useState } from 'react'
import _clone from 'lodash/clone'

import { GeneSearchContext } from 'components/search/genes/GeneSearchProvider'
import { StudySearchContext } from 'components/search/StudySearchProvider'
import SearchQueryDisplay from 'components/SearchQueryDisplay'

export default function GeneSearchView() {
  const searchContext = useContext(GeneSearchContext)
  const studySearchState = useContext(StudySearchContext)
  let [genes, setGenes] = useState(_clone(searchContext.params.genes))
  function handleSubmit(event) {
    event.preventDefault()
    searchContext.updateSearch({genes: genes}, studySearchState)
  }

  let studyFilterText = <div>Searching all studies</div>
  if (studySearchState.results.totalStudies) {
    studyFilterText = <div>
      <SearchQueryDisplay terms={studySearchState.results.terms} facets={studySearchState.results.facets}/>
      <div>({studySearchState.results.totalStudies} studies)</div>
    </div>
  }

  return (
    <div>
      { studyFilterText }
      <div className="row">
        <div className="col-md-6 col-sm-12 col-xs-12">
          <form onSubmit={ handleSubmit }>
            <div className="input-group">
              <input type="text"
                     className="form-control "
                     value={genes}
                     onChange={ (e) => setGenes(e.target.value) }
                     placeholder="Search for genes"/>
              <div className="input-group-btn">
                <button className="btn btn-info" type="submit" name="commit" id="submit-gene-search"><span className="fas fa-search"></span></button>
              </div>
            </div>
          </form>
        </div>
        <div className="col-md-6 col-sm-12 col-xs-12">
          <p className="lead">Results: <label id="gene-search-results-count" className="label label-default">0</label>
            across <label id="gene-search-studies-count" className="label label-default">0</label> studies
          </p>
        </div>
      </div>
      <div className="row">
        <div className="col-md-12">
          <div className="panel-group" id="gene-search-results">
            Results go here...
          </div>
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
