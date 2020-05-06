import { std, quantileSeq } from 'mathjs'

// default scatter plot colors, a combination of colorbrewer sets 1-3 with
// tweaks to the yellow members
//
// To consider: dedup this copy with the one that exists in application.js.
const colorBrewerSet = [
  '#e41a1c', '#377eb8', '#4daf4a', '#984ea3', '#ff7f00', '#a65628',
  '#f781bf', '#999999', '#66c2a5', '#fc8d62', '#8da0cb', '#e78ac3',
  '#a6d854', '#ffd92f', '#e5c494', '#b3b3b3', '#8dd3c7', '#bebada',
  '#fb8072', '#80b1d3', '#fdb462', '#b3de69', '#fccde5', '#d9d9d9',
  '#bc80bd', '#ccebc5', '#ffed6f'
]

// To consider: dedup this copy with the one that exists in application.js.
const plotlyDefaultLineColor = 'rgb(40, 40, 40)'

/**
 * Returns a normal reference distribution (nrd)
 *
 * Advanced Rule of thumb bandwidth selector from:
 *  https://en.wikipedia.org/wiki/Kernel_density_estimation#Bandwidth_selection
 *  and https://stat.ethz.ch/R-manual/R-devel/library/stats/html/bandwidth.html
*/
function nrd0(X) {
  // Docs: https://jstat.github.io/all.html#percentile
  // const iqr = jStat.percentile(X, 0.75) - jStat.percentile(X, 0.25)

  // Docs: https://mathjs.org/docs/reference/functions/quantileSeq.html
  const iqr = quantileSeq(X, 0.75) - quantileSeq(X, 0.25)
  const iqrM = iqr / 1.34

  // From https://jstat.github.io/all.html#stdev
  //    "Passing true to flag returns the sample standard deviation.
  //    The 'sample' standard deviation is also called the 'corrected
  //    standard deviation', and is an unbiased estimator of the population
  //    standard deviation.
  // const std = jStat.stdev(X, true)

  // From https://mathjs.org/docs/reference/functions/std.html
  //    "Optionally, the type of normalization can be specified as the final
  //    parameter. The parameter normalization can be one of the following
  //    values:
  //      ‘unbiased’ (default) The sum of squared errors is divided by (n - 1)
  const standardDeviation = std(X)

  let min = standardDeviation < iqrM ? standardDeviation : iqrM
  if (min === 0) {
    min = standardDeviation
  }
  if (min === 0) {
    min = Math.abs(X[1])
  }
  if (min === 0) {
    min = 1.0
  }
  return 0.9 * min * Math.pow(X.length, -0.2)
}

/**
 * More memory- and time-efficient analog of Math.min
 * From https://stackoverflow.com/a/13440842/10564415.
*/
function arrayMin(arr) {
  let len = arr.length; let min = Infinity
  while (len--) {
    if (arr[len] < min) {
      min = arr[len]
    }
  }
  return min
}

/**
 * More memory- and time-efficient analog of Math.max
 * From https://stackoverflow.com/a/13440842/10564415.
*/
function arrayMax(arr) {
  let len = arr.length; let max = -Infinity
  while (len--) {
    if (arr[len] > max) {
      max = arr[len]
    }
  }
  return max
}

/**
 * Creates Plotly traces and layout for violin plots and box plots
 *
 * Takes an array of arrays and returns the data array of traces and the
 * layout variable.  More specifically, this will:
 *
 * Iterate through the formatted array
 * [[name_of_trace, expression_data]...]
 * and create the response plotly objects,
 * returning [plotly data object, plotly layout object]
*/
export default function createTracesAndLayout(
  arr, title, jitter='all', expressionLabel
) {
  let data = []
  for (let x = 0; x < arr.length; x++) {
    // Plotly violin trace creation, adding to master array
    // get inputs for plotly violin creation
    const dist = arr[x][1]
    const name = arr[x][0]

    // If users want to change bandwidth, we would parameterize this.
    const bandwidth = nrd0(dist)

    // Replace the none selection with bool false for plotly
    if (jitter === '') {
      jitter = false
    }

    // Check if there is a distribution before adding trace
    if (arrayMax(dist) !== arrayMin(dist)) {
      // Make a violin plot if there is a distribution
      data = data.concat([{
        'type': 'violin',
        name,
        'y': dist,
        'points': jitter,
        'pointpos': 0,
        'jitter': 0.85,
        'spanmode': 'hard',
        'box': {
          visible: true,
          fillcolor: '#ffffff',
          width: .1
        },
        bandwidth,
        'marker': {
          size: 2,
          color: '#000000',
          opacity: 0.8
        },
        'fillcolor': colorBrewerSet[x % 27],
        'line': {
          color: '#000000',
          width: 1.5
        },
        'meanline': {
          visible: false
        }
      }])
    } else {
      // Make a boxplot for data with no distribution
      data = data.concat([{
        type: 'box',
        name,
        y: dist,
        boxpoints: jitter,
        marker: {
          color: colorBrewerSet[x % 27],
          size: 2,
          line: {
            color: plotlyDefaultLineColor
          }
        },
        boxmean: true
      }])
    }
  }

  const layout = {
    title,
    // Force axis labels, including number strings, to be treated as
    // categories.  See Python docs (same generic API as JavaScript):
    // https://plotly.com/python/axes/#forcing-an-axis-to-be-categorical
    // Relevant Plotly JS example:
    // https://plotly.com/javascript/axes/#categorical-axes
    xaxis: {
      type: 'category'
    },
    yaxis: {
      zeroline: true,
      showline: true,
      title: expressionLabel
    },
    margin: {
      pad: 10,
      b: 100
    },
    autosize: true
  }

  return [data, layout]
}
