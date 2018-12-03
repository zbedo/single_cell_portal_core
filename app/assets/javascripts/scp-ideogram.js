//    Not used currently, but perhaps later.
//   function getGenomicRange(annot) {
//     var chr, start, stop, startString, stopString, genomicRange;
//
//     // Get genomic range
//     chr = annot.chr;
//     start = annot.start;
//     stop = start + annot.length;
//     startString = start.toLocaleString();
//     stopString = stop.toLocaleString();
//     genomicRange = 'chr' + chr + ':' + startString + '-' + stopString;
//
//     return genomicRange;
//   }
//
//   function getEnsemblLink(annot) {
//     var url, link;
//     url = 'https://www.ensembl.org/' + annot.id;
//     link = '<a target="_blank" href="' + url + '">' + annot.name + '</a>';
//     return link;
//   }
//
//   function writeAnnotsTable() {
//
//     var chr, annots, datum, row, header, table, annotsContainer, keys,
//         genomicRange, ensemblLink, key, i, j, k, displayKeys;
//
//     rows = [];
//
//     annotsContainer = ideogram.annots;
//
//     keys = ideogram.rawAnnots.keys;
//
//     for (i = 0; i < annotsContainer.length; i++) {
//       chr = annotsContainer[i].chr;
//       annots = annotsContainer[i].annots;
//       for (j = 0; j < annots.length; j++) {
//         annot = annots[j];
//         row = [];
//
//         genomicRange = getGenomicRange(annot);
//         ensemblLink = getEnsemblLink(annot);
//
//         for (k = 0; k < keys.length; k++) {
//           key = keys[k];
//           if (key === 'name') {
//             datum = ensemblLink;
//           } else if (key === 'start') {
//             datum = genomicRange;
//           } else if (key === 'id') {
//             continue;
//           } else {
//             datum = annot[key];
//           }
//           row.push(datum)
//
//         }
//         row = '<tr><td>' + row.join('</td><td>') + '</td></tr>';
//         rows.push(row);
//       }
//     }
//
//     displayKeys = [];
//     for (i = 0; i < keys.length; i++) {
//       key = keys[i];
//       if (key == 'start') {
//         key = 'Genomic range';
//       } else if (key === 'id') {
//         continue;
//       } else {
//         key = key[0].toUpperCase() + key.slice(1);
//       }
//       displayKeys.push(key)
//     }
//
//     header = '<tr><th>' + displayKeys.join('</th><th>') + '</th></tr>';
//
//     table =
//       '<table class="table table-striped table-sm">' +
//         '<thead>' + header + '</thead>' +
//         '<tbody>' + rows + '</tbody>' +
//       '</table>';
//
//     $('#ideogram-container').append(table);
//   }

var ideoAnnotPathStem = '/single_cell/example_data/ideogram_exp_means/ideogram_exp_means__';

var annotHeight = 3.5;
var ideoAnnotShape =
  'm0,0 l 0 ' + (2 * annotHeight) +
  'l ' + annotHeight/2 + ' 0' +
  'l 0 -' + (2 * annotHeight) + 'z';

// Intercept requests to add bearer token, enabling direct load of files from GCS
var originalFetch = window.fetch;
window.fetch = function () {
  var myHeaders = new Headers({
    'Authorization': 'Bearer ' + accessToken
  });
  arguments[1] = {headers: myHeaders};
  return originalFetch.apply(this, arguments)
};

// Use colors like inferCNV; see
// https://github.com/broadinstitute/inferCNV/wiki#demo-example-figure
var heatmapThresholds = [
  ['-0.001', '#F33'], // If expression value < 0 (-0.001), use blue (alt. purple: #551ABB)
  ['0', '#CCC'], // If value == 0, use grey
  ['+', '#33F'] // If value > 0, use red (alt. orange: #FFA500)
];

var legend = [{
  name: 'Expression level',
  rows: [
    {name: 'Low', color: '#33F'},
    {name: 'Normal', color: '#CCC'},
    {name: 'High', color: '#F33'}
  ]
}];

function getSelectedTracks() {
  var selectedTracks = [];

  checkboxes.forEach(function(checkbox) {
    var trackIndex = parseInt(checkbox.getAttribute('id').split('_')[1]);
    if (checkbox.checked) {
      selectedTracks.push(trackIndex);
    }
  });

  return selectedTracks;
}

function updateTracks() {
  var selectedTracks = getSelectedTracks();
  ideogram.updateDisplayedTracks(selectedTracks);
}

function createTrackFilters() {
  var i, listItems, trackLabels, content, checked;
  // Only apply this function once
  if (document.querySelector('#filter_1')) return;
  listItems = '';
  trackLabels = ideogram.rawAnnots.keys.slice(6,);
  for (i = 0; i < trackLabels.length; i++) {
    checked = ([0, 1, 2].includes(i)) ? 'checked' : '';
    listItems +=
      '<li>' +
        '<label for="filter_' + (i + 1) + '">' +
          '<input type="checkbox" id="filter_'  + (i + 1) + '" ' + checked + '/>' +
          trackLabels[i] +
        '</label>' +
      '</li>';
  }
  content = 'Tracks to display ' + listItems;
  document.querySelector('#tracks-to-display').innerHTML = content;
  checkboxes = document.querySelectorAll('input[type=checkbox]');
  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('click', function() {
      updateTracks();
    });
  });
}

function defineHeatmaps() {
  var i, labels, heatmaps, annotationTracks;

  heatmaps = [];
  labels = ideogram.rawAnnots.keys.slice(3,);

  annotationTracks = [];

  for (i = 0; i < labels.length; i++) {
    heatmaps.push({key: labels[i], thresholds: heatmapThresholds});
    annotationTracks.push({id: labels[i], shape: ideoAnnotShape});
  }

  ideogram.config.heatmaps = heatmaps;
  ideogram.config.annotationTracks = annotationTracks;
}

function getIdeogramAnnotationPaths() {
  var paths, clusters = [], cellAnnots = [];

  paths = [];

  $('#cluster option').each((i, el) => clusters.push($(el).val()));
  $('#annotation option').each((i, el) => {
    var cellAnnot = $(el).attr('value');
    if (cellAnnot.split('--').slice(-2)[0] === 'group') {
      cellAnnots.push(cellAnnot);
    }
  });

  clusters.forEach(cluster => {
    cellAnnots.forEach(cellAnnot => {
      paths.push(ideoAnnotPathStem + cluster + '--' + cellAnnot + '.json');
    });
  });

  return paths;
}

function warnOfNumericCluster() {
  var cluster, cellAnnot, warning;

  cluster = $('#cluster option:selected').val();
  cellAnnot = $('#annotation option:selected').val();

  warning =
    '<div style="height: 400px; margin-left: 20px;">' +
      'Ideogram not available, as selected cluster ("' + cluster + '") and ' +
      'cell annotation ("' + cellAnnot + '") are numeric.' +
    '</div>';

  document.querySelector('#_ideogramOuterWrap').innerHTML = warning;
}

$(document).on('change', '#cluster, #annotation', function(el) {
  var cluster, cellAnnot, path;

  delete window.ideogram;
  document.querySelector('#tracks-to-display').innerHTML = '';
  document.querySelector('#_ideogramOuterWrap').innerHTML = '';

  cluster = $('#cluster option:selected').attr('value');
  cellAnnot = $('#annotation option:selected').attr('value');
  path = ideoAnnotPathStem + cluster + '--' + cellAnnot + '.json'

  if (path.indexOf('--numeric--') !== -1) {
    warnOfNumericCluster();
  } else {
    initializeIdeogram(path);
  }
});

function initializeIdeogram(url) {

  if (typeof url === 'undefined') {
    url = getIdeogramAnnotationPaths()[0];
  }

  window.ideogram = new Ideogram({
    container: '#ideogram-container',
    organism: ideogramInferCnvSettings.organism.toLowerCase(),
    assembly: ideogramInferCnvSettings.assembly,
    chrHeight: 400,
    dataDir: 'https://unpkg.com/ideogram@1.4.0/dist/data/bands/native/',
    annotationsPath: url,
    annotationsLayout: 'heatmap',
    annotationsNumTracks: 3,
    annotationsDisplayedTracks: [1, 2, 3],
    legend: legend,
    onLoadAnnots: defineHeatmaps,
    onDrawAnnots: createTrackFilters,
    debug: true,
    rotatable: false
  });
}