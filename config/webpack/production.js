process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')

process.env.BARD_DOMAIN = 'https://terra-bard-prod.appspot.com'

module.exports = environment.toWebpackConfig()
