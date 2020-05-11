import Plotly from 'plotly.js-dist'

/** Plots expression data.  Needed for mocking in related test. */
export function plot(graphElementId, expressionData, expressionLayout) {
  Plotly.newPlot(
    graphElementId,
    expressionData,
    expressionLayout
  )
}
