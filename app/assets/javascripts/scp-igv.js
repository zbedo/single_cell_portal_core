$(document).on('click', '.bam-browse-genome', function(e) {

  var selectedBam, thisBam, i;

  selectedBam = $(this).attr('data-filename');

  // bamAndBaiFiles declared in _genome.html.erb
  for (i = 0; i < bamAndBaiFiles.length; i++) {
    thisBam = bamAndBaiFiles[i].url.split('\/o/')[1].split('?')[0];
    if (thisBam === selectedBam) {
      bamsToViewInIgv.push(bamAndBaiFiles[i]);
    }
  }

  $('#genome-tab-nav').css('display', ''); // Show Genome tab
  $('#study-visualize-nav > a').click();
  $('#genome-tab-nav > a').click();
});

$(document).on('click', '#genome-tab-nav', function (e) {
  initializeIgv();
});

function initializeIgv() {
  var igvContainer, igvOptions, igvTracks, i, bam, genome,
    genesTrack, bamTrack, genesTrackName, queriedGenes, gene,
    defaultGenomeLocation;

  igvContainer = document.getElementById('igv-container');

  // TODO: Remove hard-coding
  genome = 'mm10';
  genesTrackName = 'Genes | GENCODE M17';

  genesTrack = {
    name: genesTrackName,
    url: bedFiles[genome].url + '?alt=media',
    indexURL: bedFiles[genome].indexUrl + '?alt=media',
    type: 'annotation',
    format: 'bed',
    sourceType: 'file',
    order: 0,
    visibilityWindow: 300000000,
    displayMode: 'EXPANDED',
    oauthToken: accessToken
  };

  igvTracks = [genesTrack];

  for (i = 0; i < bamsToViewInIgv.length; i++) {
    bam = bamsToViewInIgv[i];
    bamTrack = {
      url: bam.url,
      indexURL: bam.indexUrl,
      oauthToken: accessToken,
      label: bam.url.split('/o/')[1].split('?')[0]
    };
    igvTracks.push(bamTrack);
  }

  queriedGenes = $('.queried-gene');

  if (queriedGenes.length === 0) {
    // TODO: Use highest-weighted gene in expression matrix
    // Will require improved back-end gene model, and/or client-side API calls to NCBI EUtils
    defaultGenomeLocation = ['myc'];
  } else {
    defaultGenomeLocation =
      queriedGenes.toArray()
        .map(gene => $(gene).text()) // Get name of each gene
        .slice(0, 3); // Only show up to three genes
  }

  igvOptions = {
    genome: genome,
    showIdeogram: false,
    locus: defaultGenomeLocation,
    tracks: igvTracks,
    supportQueryParameters: true
  };

  igv.createBrowser(igvContainer, igvOptions);

}