/* eslint-disable */

legend = [{
  name: 'Expression level',
  rows: [
    { name: 'Low', color: '#00B' },
    { name: 'Normal', color: '#DDD' },
    { name: 'High', color: '#F00' }
  ]
}]

function initializeIdeogram() {
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
  // width: 550px;

  window.ideoConfig = {
    container: '#ideogramSearchResultsContainer',
    organism: 'mouse',
    chrHeight: 85,
    chrLabelSize: 10,
    annotationHeight: 5,
    chrWidth: 8,
    dataDir: 'https://unpkg.com/ideogram@1.19.0/dist/data/bands/native/',
    legend: legend,
    debug: true,
    rotatable: false,
    showFullyBanded: false,
    onLoad: function() {
      const left = document.querySelector('#_ideogramInnerWrap').style['max-width'];
      document.querySelector('#ideogramSearchResultsContainer').style.width = left;
    }
  }

  window.ideogram = new Ideogram(window.ideoConfig)
}
