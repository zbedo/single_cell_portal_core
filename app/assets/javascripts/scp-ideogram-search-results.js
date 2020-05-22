/* eslint-disable */

function onClickAnnot(annot) {
  document.querySelector('#search_genes').value = annot.name;
  document.querySelector('#perform-gene-search').click();
  plotRelatedGenes([annot.name]);
}

// Process text input for the "Search" field.
function handleSearch(event) {
  // Ignore non-"Enter" keyups
  if (event.type === 'keyup' && event.keyCode !== 13) return;

  var searchInput = event.target.value.trim();

  // Handles "BRCA1,BRCA2", "BRCA1 BRCA2", and "BRCA1, BRCA2"
  let geneSymbols = searchInput.split(/[, ]/).filter(d => d !== '')
  plotRelatedGenes(geneSymbols);
}


function createSearchResultsIdeogram() {
  if (typeof window.ideogram !== 'undefined') {
    delete window.ideogram
    $('#_ideogramOuterWrap').html('')
  }

  $('#ideogramWarning, #ideogramTitle').remove();

  document.querySelector('#ideogramSearchResultsContainer').style =
    `position: relative;
    top: -60px;
    height: 0;
    float: right`;

  ideoConfig = {
    container: '#ideogramSearchResultsContainer',
    organism: window.SCP.organism.toLowerCase().replace(/ /g, '-'),
    chrWidth: 8,
    chrHeight: 80,
    chrLabelSize: 11,
    annotationHeight: 5,
    dataDir: 'https://unpkg.com/ideogram@1.20.0/dist/data/bands/native/',
    onClickAnnot: onClickAnnot,
    onLoad: function() {
      let left = document.querySelector('#_ideogramInnerWrap').style['max-width'];
      left = (parseInt(left.slice(0, -2)) + 90);
      document.querySelector('#ideogramSearchResultsContainer').style.width = left + 'px';

      var searchInput = document.querySelector('#search_genes').value.trim();

      // Handles "BRCA1,BRCA2", "BRCA1 BRCA2", and "BRCA1, BRCA2"
      let geneSymbols = searchInput.split(/[, ]/).filter(d => d !== '')
      // plotGeneAndParalogs(geneSymbols);
      this.plotRelatedGenes(geneSymbols);
    }
  }

  let ideogram = Ideogram.initRelatedGenes(ideoConfig)
}
