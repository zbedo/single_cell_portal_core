const { environment } = require('@rails/webpacker')

environment.loaders.delete('nodeModules')

// Set the max parallelization for the minification pipeline
// See https://github.com/webpack-contrib/terser-webpack-plugin/issues/143#issuecomment-573954013
//      for a description of the issue
// See https://github.com/rails/webpacker/issues/2131 for discussion on how the configuration
//      is applied through webpacker
if (environment.config.optimization) {
  environment.config.optimization.minimizer.find(m => m.constructor.name === 'TerserPlugin').options.terserOptions.parallel = 4
  environment.config.optimization.minimizer.find(m => m.constructor.name === 'TerserPlugin').options.parallel = 4
}


module.exports = environment
