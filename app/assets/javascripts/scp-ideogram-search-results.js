/* eslint-disable */

// fetchEnsembl = Ideogram.fetchEnsembl;

annotDescriptions = {}

function onClickAnnot(annot) {
  document.querySelector('#search_genes').value = annot.name;
  document.querySelector('#perform-gene-search').click();
  // plotGeneAndParalogs([annot.name]);
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

var chrHeight = 90;
var shape = 'triangle';
var left = 0;

var ensemblBase = 'https://rest.ensembl.org';

/**
 * Retrieve interacting genes from WikiPathways API
 *
 * Docs:
 * https://webservice.wikipathways.org/ui/
 * https://www.wikipathways.org/index.php/Help:WikiPathways_Webservice/API
 *
 * Examples:
 * https://webservice.wikipathways.org/findInteractions?query=ACE2&format=json
 * https://webservice.wikipathways.org/findInteractions?query=RAD51&format=json
 */
async function fetchInteractingGenes(gene, organism) {
  let ixns = {};
  let seenNameIds = {}
  let orgNameSimple = organism.replace(/-/g, ' ');
  const queryString = `?query=${gene.name}&format=json`
  const url =
    `https://webservice.wikipathways.org/findInteractions${queryString}`;
  response = await fetch(url)
  data = await response.json()
  data.result.forEach(interaction => {
    if (interaction.species.toLowerCase() === orgNameSimple) {
      var right = interaction.fields.right.values;
      var left = interaction.fields.left.values;
      var rawIxns = right.concat(left)
      var name = interaction.name;
      var id = interaction.id;

      rawIxns.forEach(rawIxn => {
        let nameId = name + id;
        if (
          maybeGeneSymbol(rawIxn, gene) &&
          !(nameId in seenNameIds)
        ) {
          seenNameIds[nameId] = 1;
          let ixn = {name: name, pathwayId: id}
          if (rawIxn in ixns) {
            ixns[rawIxn].push(ixn)
          } else {
            ixns[rawIxn] = [ixn]
          }
        }
      })
    }
  })

  return ixns;
}

async function fetchMyGeneInfo(queryString) {
  const myGeneBase = 'https://mygene.info/v3/query';
  let response = await fetch(myGeneBase + queryString);
  let data = await response.json();
  return data;
}

function maybeGeneSymbol(ixn, gene) {
  return (
    ixn !== '' &&
    !ixn.includes(' ') &&
    ixn.toLowerCase() !== gene.name.toLowerCase()
  );
}

/**
 * Retrieves positions of interacting genes from MyGene.info
 *
 * Docs:
 * https://docs.mygene.info/en/v3/
 *
 * Example:
 * https://mygene.info/v3/query?q=symbol:cdk2%20OR%20symbol:brca1&species=9606&fields=symbol,genomic_pos,name
 */
async function fetchInteractingGeneAnnots(interactions) {

  let annots = [];
  let geneList = Object.keys(interactions);
  const pathwaysBase = 'https://www.wikipathways.org/index.php/Pathway:';

  if (geneList.length === 0) return annots

  ixnParam = geneList.map(ixn => `symbol:${ixn}`).join(' OR ')

  const taxid = ideogram.config.taxid;
  const queryString =
    `?q=${ixnParam}&species=${taxid}&fields=symbol,genomic_pos,name`;
  let data = await fetchMyGeneInfo(queryString)

  data.hits.forEach(hit => {
    annot = {
      name: hit.symbol,
      chr: hit.genomic_pos.chr,
      start: hit.genomic_pos.start,
      stop: hit.genomic_pos.end,
      id: hit.genomic_pos.ensemblgene,
      color: 'purple'
    }
    annots.push(annot)

    const ixns = interactions[hit.symbol];

    const links = ixns.map(ixn => {
      const url = `${pathwaysBase}${ixn.pathwayId}`
      return `<a href="${url}" target="_blank">${ixn.name}</a>`;
    }).join('<br/>')

    const description = `
      ${hit.name}<br/><br/>
      Interacts in pathways:<br/>
      ${links}`;

    annotDescriptions[hit.symbol] = description;
  })

  return annots;
}

/**
 * Fetch paralogs of searched gene
 */
async function fetchParalogPositions(annot, annots) {
  const taxid = ideogram.config.taxid;
  const orgUnderscored = ideogram.config.organism.replace(/[ -]/g, '_');

  const params = `&format=condensed&type=paralogues&target_taxon=${taxid}`;
  let path = `/homology/id/${annot.id}?${params}`
  const ensemblHomologs = await fetchEnsembl(path);
  const homologs = ensemblHomologs.data[0].homologies;

  // Fetch positions of paralogs
  homologIds = homologs.map(homolog => homolog.id)
  path = '/lookup/id/' + orgUnderscored;
  let body = {
    'ids': homologIds,
    'species': orgUnderscored,
    'object_type': 'gene'
  }
  const ensemblHomologGenes = await fetchEnsembl(path, body, 'POST');

  Object.entries(ensemblHomologGenes).map((idGene, i) => {
    let gene = idGene[1]
    annot = {
      name: gene.display_name,
      chr: gene.seq_region_name,
      start: gene.start,
      stop: gene.end,
      id: gene.id,
      shape: 'triangle',
      color: 'pink'
    };
    // Add to start of array, so searched gene gets top z-index
    annots.unshift(annot);
    annotDescriptions[annot.name] = gene.description;
  })

  return annots;
}

async function plotRelatedGenes(geneSymbols) {

  organism = ideogram.config.organism;

  // Refine style
  document.querySelectorAll('.chromosome').forEach(chromosome => {
    chromosome.style.cursor = '';
  })
  var legendLeft = left - 90 - 40;
  var topPx = chrHeight + 20;
  var style =
    `float: left; position: relative; top: -${topPx}px; left: ${legendLeft}px;`;

  // Fetch positon of searched gene
  const taxid = ideogram.config.taxid;
  const queryString =
    `?q=symbol:${geneSymbols[0]}&species=${taxid}&fields=symbol,genomic_pos,name`;
  let data = await fetchMyGeneInfo(queryString)

  const gene = data.hits[0]
  annotDescriptions[gene.symbol] = gene.name;

  let annots = [];

  let annot = {
    name: gene.symbol,
    chr: gene.genomic_pos.chr,
    start: gene.genomic_pos.start,
    stop: gene.genomic_pos.end,
    id: gene.genomic_pos.ensemblgene,
    color: 'red'
  };
  annots.push(annot)

  interactions = await fetchInteractingGenes(annot, organism);
  interactingAnnots = await fetchInteractingGeneAnnots(interactions)
  annots = annots.concat(interactingAnnots)

  paralogs = await fetchParalogPositions(annot, annots)

  annots.sort((a, b) => { return b.name.length - a.name.length })

  ideogram.drawAnnots(annots);

  document.querySelector('#_ideogramLegend').style = style;
}

function decorateGene(annot) {
  var org = ideogram.getScientificName(ideogram.config.taxid);
  var term = `(${annot.name}[gene])+AND+(${org}[orgn])`;
  var url = `https://ncbi.nlm.nih.gov/gene/?term=${term}`;
  var description = annotDescriptions[annot.name].split(' [')[0];
  annot.displayName =
    `<a target="_blank" href="${url}">${annot.name}</a>
    <br/>
    ${description}
    <br/>`;
  return annot
}

var searchResultsLegend = [{
  name: 'Click gene to search',
  rows: [
    {name: 'Interacting gene', color: 'purple', shape: shape},
    {name: 'Paralogous gene', color: 'pink', shape: shape},
    {name: 'Searched gene', color: 'red', shape: shape}
  ]
}];

async function fetchEnsembl(path, body=null, method='GET') {
  let init = {
    method: method,
    headers: {'Content-Type': 'application/json'}
  }
  if (body !== null) init.body = JSON.stringify(body);
  var response = await fetch(ensemblBase + path, init);
  var json = await response.json();
  return json;
}

function createSearchResultsIdeogram() {
  if (typeof window.ideogram !== 'undefined') {
    delete window.ideogram
    $('#_ideogramOuterWrap').html('')
  }

  var organism = window.SCP.organism;

  $('#ideogramWarning, #ideogramTitle').remove();

  document.querySelector('#ideogramSearchResultsContainer').style =
    `position: relative;
    top: -60px;
    height: 0;
    float: right`;

  window.ideoConfig = {
    container: '#ideogramSearchResultsContainer',
    organism: organism.toLowerCase().replace(/ /g, '-'),
    chrHeight: 80,
    chrLabelSize: 11,
    annotationHeight: 5,
    chrWidth: 8,
    dataDir: 'https://unpkg.com/ideogram@1.19.0/dist/data/bands/native/',
    legend: searchResultsLegend,
    debug: true,
    rotatable: false,
    showFullyBanded: false,
    onClickAnnot: onClickAnnot,
    onWillShowAnnotTooltip: decorateGene,
    onLoad: function() {
      left = document.querySelector('#_ideogramInnerWrap').style['max-width'];
      left = (parseInt(left.slice(0, -2)) + 90);
      document.querySelector('#ideogramSearchResultsContainer').style.width = left + 'px';

      var searchInput = document.querySelector('#search_genes').value.trim();

      // Handles "BRCA1,BRCA2", "BRCA1 BRCA2", and "BRCA1, BRCA2"
      let geneSymbols = searchInput.split(/[, ]/).filter(d => d !== '')
      // plotGeneAndParalogs(geneSymbols);
      plotRelatedGenes(geneSymbols);
    }
  }

  window.ideogram = new Ideogram(window.ideoConfig);
}
