process.env.NODE_ENV = process.env.NODE_ENV || 'staging'

const environment = require('./environment')

process.env.BARD_DOMAIN = 'https://terra-bard-alpha.appspot.com'

module.exports = environment.toWebpackConfig()
