/**
 * Returns a normal reference distribution (nrd)
 *
 * Advanced Rule of thumb bandwidth selector from:
 *  https://en.wikipedia.org/wiki/Kernel_density_estimation#Bandwidth_selection
 *  and https://stat.ethz.ch/R-manual/R-devel/library/stats/html/bandwidth.html
*/
function nrd0(X) {
  const iqr = jStat.percentile(X, 0.75) - jStat.percentile(X, 0.25)
  const iqrM = iqr /1.34
  const std = jStat.stdev(X, true)
  let min = std < iqrM ? std : iqrM
  if (min === 0) {
    min = std
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
 * Creates Plotly traces
 * Takes an array of arrays and returns the data array of traces and the
 * layout variable.  More specifically, this will:
 *
 * Iterate through the formatted array
 * [[name_of_trace, expression_data]...]
 * and create the response plotly objects,
 * returning [plotly data object, plotly layout object]
*/
function createTracesAndLayout(
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
