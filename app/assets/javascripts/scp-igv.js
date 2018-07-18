/**
 * @fileoverview Functions and event handlers for igv.js genome browser.
 * Provides a way to view nucleotide sequencing reads in genomic context.
 */

// Persists 'Genome' tab and IGV embed across view states.
// Ensures that IGV doesn't disappear when user clicks 'Browse in genome' in
// default view, then searches a gene.
window.hasDisplayedIgv = false;

$(document).on('click', '.bam-browse-genome', function(e) {
  var selectedBam, thisBam, i;

  selectedBam = $(this).attr('data-filename');

  // bamAndBaiFiles assigned in _genome.html.erb
  for (i = 0; i < bamAndBaiFiles.length; i++) {
    thisBam = bamAndBaiFiles[i].url.split('\/o/')[1].split('?')[0];
    if (thisBam === selectedBam) {
      bamsToViewInIgv.push(bamAndBaiFiles[i]);
    }
  }

  $('#genome-tab-nav').css('display', ''); // Show 'Genome' tab
  $('#study-visualize-nav > a').click();
  $('#genome-tab-nav > a').click();

  hasDisplayedIgv = true;
});

$(document).on('click', '#genome-tab-nav', function (e) {
  initializeIgv();
});

/**
 * Get tracks for selected BAM files, to show sequencing reads
 */
function getBamTracks() {
  var bam, bamTrack, bamTracks, i, bamFileName;

  bamTracks = [];

  for (i = 0; i < bamsToViewInIgv.length; i++) {
    bam = bamsToViewInIgv[i];

    // Extracts BAM file name from its GCS API URL
    bamFileName = bam.url.split('/o/')[1].split('?')[0];

    bamTrack = {
      url: bam.url,
      indexURL: bam.indexUrl,
      oauthToken: accessToken,
      label: bamFileName
    };
    bamTracks.push(bamTrack);
  }

  return bamTracks;
}

/**
 * Gets the track of genes and transcripts from the genome's BED file
 */
function getGenesTrack(genome, genesTrackName) {
  var bedFile, genesTrack;

  // bedFiles assigned in _genome.html.erb
  bedFile = bedFiles[genome];

  genesTrack = {
    name: genesTrackName,
    url: bedFile.url + '?alt=media',
    indexURL: bedFile.indexUrl + '?alt=media',
    type: 'annotation',
    format: 'bed',
    sourceType: 'file',
    order: 0,
    visibilityWindow: 300000000,
    displayMode: 'EXPANDED',
    oauthToken: accessToken // Assigned in _genome.html.erb
  };

  genesTrack = {
    name: genesTrackName,
    // url: bedFile.url + '?alt=media',
    // indexURL: bedFile.indexUrl + '?alt=media',
    url: 'https://www.googleapis.com/storage/v1/b/fc-bcc55e6c-bec3-4b2e-9fb2-5e1526ddfcd2/o/reference_data%2Fmouse%2Fmm10%2Fgencode.vM17.annotation.possorted.gtf.gz?alt=media',
    indexURL: 'https://www.googleapis.com/storage/v1/b/fc-bcc55e6c-bec3-4b2e-9fb2-5e1526ddfcd2/o/reference_data%2Fmouse%2Fmm10%2Fgencode.vM17.annotation.possorted.gtf.gz.tbi?alt=media',
    type: 'annotation',
    format: 'gtf',
    sourceType: 'file',
    order: 0,
    visibilityWindow: 300000000,
    displayMode: 'EXPANDED',
    oauthToken: accessToken // Assigned in _genome.html.erb
  };

  return genesTrack;
}

/**
 * Instantiates and renders igv.js widget on the page
 */
function initializeIgv() {
  var igvContainer, igvOptions, tracks, genome, genesTrack, bamTracks,
    genesTrackName, genes, locus;

  igvContainer = document.getElementById('igv-container');

  genes = $('.queried-gene');
  locus = (genes.length === 0) ? ['myc'] : [genes.first().text()];

  // TODO: Remove hard-coding of genome after SCP species integration
  genome = 'mm10';
  genesTrackName = 'Genes | GENCODE M17';
  genesTrack = getGenesTrack(genome, genesTrackName);
  bamTracks = getBamTracks();
  tracks = [genesTrack].concat(bamTracks);

  igvOptions = {
    genome: genome,
    locus: locus,
    tracks: tracks,
    supportQueryParameters: true
  };

  igv.createBrowser(igvContainer, igvOptions);
}