process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const environment = require('./environment')

process.env.BARD_DOMAIN = 'https://terra-bard-dev.appspot.com'

module.exports = environment.toWebpackConfig()
